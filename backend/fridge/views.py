import json
import logging
import re
from decimal import Decimal, InvalidOperation, ROUND_HALF_UP
from socket import timeout as SocketTimeout
from urllib.error import HTTPError, URLError
from urllib.parse import quote
from urllib.request import Request, urlopen

from rest_framework import generics, status
from rest_framework.permissions import IsAuthenticated
from rest_framework.response import Response
from rest_framework.views import APIView

from .models import Product
from .serializers import ProductSerializer
import base64
from io import BytesIO

from django.conf import settings
from django.db.models import F
from openai import OpenAI
from PIL import Image, UnidentifiedImageError
from pydantic import BaseModel, Field, ValidationError
from rest_framework.parsers import MultiPartParser, FormParser

from households.models import FamilyActivity


logger = logging.getLogger(__name__)

MAX_RECEIPT_SIZE = 10 * 1024 * 1024
RECEIPT_IMAGE_FORMATS = {
    'JPEG': 'image/jpeg',
    'PNG': 'image/png',
    'WEBP': 'image/webp',
}


class ReceiptProduct(BaseModel):
    name: str = Field(min_length=1)
    quantity: int = Field(default=1, ge=1)
    unit: str = Field(default='adet', min_length=1)


class ReceiptAnalysis(BaseModel):
    products: list[ReceiptProduct]


class ReceiptImageError(ValueError):
    pass


def receipt_image_media_type(image_bytes):
    try:
        with Image.open(BytesIO(image_bytes)) as image:
            image.verify()
            image_format = image.format
    except (UnidentifiedImageError, OSError, ValueError) as exc:
        raise ReceiptImageError('Geçerli bir fiş görseli gönderilmedi.') from exc

    media_type = RECEIPT_IMAGE_FORMATS.get(image_format)
    if media_type is None:
        raise ReceiptImageError(
            'Yalnızca JPEG, PNG veya WEBP görseller destekleniyor.'
        )
    return media_type


def parse_receipt_response(response):
    if response.output_parsed is not None:
        return response.output_parsed.model_dump()

    raw_text = response.output_text.strip()
    fenced_match = re.fullmatch(
        r'```(?:json)?\s*(.*?)\s*```',
        raw_text,
        flags=re.IGNORECASE | re.DOTALL,
    )
    if fenced_match:
        raw_text = fenced_match.group(1).strip()

    return ReceiptAnalysis.model_validate_json(raw_text).model_dump()


QUANTITY_UNITS = {
    'kg': ('g', Decimal('1000')),
    'g': ('g', Decimal('1')),
    'l': ('ml', Decimal('1000')),
    'lt': ('ml', Decimal('1000')),
    'liter': ('ml', Decimal('1000')),
    'litre': ('ml', Decimal('1000')),
    'dl': ('ml', Decimal('100')),
    'cl': ('ml', Decimal('10')),
    'ml': ('ml', Decimal('1')),
    'adet': ('adet', Decimal('1')),
    'piece': ('adet', Decimal('1')),
    'pieces': ('adet', Decimal('1')),
}


def normalize_product_quantity(product):
    """Return an integer amount and model-friendly unit when OFF has enough data."""
    raw_value = product.get('product_quantity')
    raw_unit = str(product.get('product_quantity_unit') or '').strip().lower()

    if raw_value is None or not raw_unit:
        quantity_match = re.search(
            r'(\d+(?:[.,]\d+)?)\s*(kg|g|ml|cl|dl|l|lt|litre|liter|adet)\b',
            str(product.get('quantity') or ''),
            flags=re.IGNORECASE,
        )
        if not quantity_match:
            return None, ''
        raw_value, raw_unit = quantity_match.groups()
        raw_unit = raw_unit.lower()

    normalized_unit = QUANTITY_UNITS.get(raw_unit)
    if normalized_unit is None:
        return None, ''

    try:
        value = Decimal(str(raw_value).replace(',', '.'))
    except InvalidOperation:
        return None, ''

    if not value.is_finite() or value <= 0:
        return None, ''

    unit, multiplier = normalized_unit
    amount = (value * multiplier).quantize(Decimal('1'), rounding=ROUND_HALF_UP)
    return int(amount), unit


class ProductListCreateView(generics.ListCreateAPIView):
    serializer_class = ProductSerializer
    permission_classes = [IsAuthenticated]

    def get_queryset(self):
        household = self.request.user.households.first()

        if household:
            return Product.objects.filter(
                household=household
            ).order_by(F('expiry_date').asc(nulls_last=True), 'name')

        return Product.objects.filter(
            owner=self.request.user
        ).order_by(F('expiry_date').asc(nulls_last=True), 'name')

    def perform_create(self, serializer):
        household = self.request.user.households.first()

        product = serializer.save(
            owner=self.request.user,
            household=household
        )

        if household:
            try:
                FamilyActivity.objects.create(
                    household=household,
                    user=self.request.user,
                    action_type='product_added',
                    message=(
                        f'{self.request.user.get_username()} '
                        f'buzdolabına {product.name} ekledi.'
                    ),
                )
            except Exception:
                logger.exception(
                    'Product %s was created, but its family activity could not be saved.',
                    product.pk,
                )


class ProductDetailView(generics.RetrieveUpdateDestroyAPIView):
    serializer_class = ProductSerializer
    permission_classes = [IsAuthenticated]

    def get_queryset(self):
        household = self.request.user.households.first()

        if household:
            return Product.objects.filter(
                household=household
            )

        return Product.objects.filter(
            owner=self.request.user
        )

    def perform_update(self, serializer):
        product = serializer.save()
        household = product.household

        if household:
            try:
                FamilyActivity.objects.create(
                    household=household,
                    user=self.request.user,
                    action_type='product_updated',
                    message=(
                        f'{self.request.user.get_username()} '
                        f'{product.name} ürününü güncelledi.'
                    ),
                )
            except Exception:
                logger.exception(
                    'Product %s was updated, but its family activity could not be saved.',
                    product.pk,
                )

    def perform_destroy(self, instance):
        product_name = instance.name
        household = instance.household

        instance.delete()

        if household:
            FamilyActivity.objects.create(
                household=household,
                user=self.request.user,
                action_type='product_deleted',
                message=(
                    f'{self.request.user.get_username()} '
                    f'buzdolabından {product_name} sildi.'
                ),
            )


class ProductConsumeView(ProductDetailView):
    def post(self, request, *args, **kwargs):
        product = self.get_object()
        product_id = product.pk
        product_name = product.name
        household = product.household

        product.delete()

        if household:
            try:
                FamilyActivity.objects.create(
                    household=household,
                    user=request.user,
                    action_type='product_consumed',
                    message=(
                        f'{request.user.get_username()} '
                        f'{product_name} ürününü tükendi olarak işaretledi.'
                    ),
                )
            except Exception:
                logger.exception(
                    'Product %s was consumed, but its family activity could not be saved.',
                    product_id,
                )

        return Response(status=status.HTTP_204_NO_CONTENT)


class BarcodeLookupView(APIView):
    permission_classes = [IsAuthenticated]

    def get(self, request, barcode):
        barcode = barcode.strip()
        logger.info("Barcode lookup requested: barcode=%s", barcode)

        if not barcode.isdigit() or not 8 <= len(barcode) <= 14:
            return Response(
                {"detail": "Geçersiz barkod.", "barcode": barcode},
                status=400,
            )

        url = (
            "https://world.openfoodfacts.org/api/v2/product/"
            f"{quote(barcode, safe='')}.json"
            "?fields=code,product_name,brands,quantity,product_quantity,product_quantity_unit,image_front_url"
        )
        api_request = Request(
            url,
            headers={
                "User-Agent": "SmartFridge/1.0 (barcode lookup)",
                "Accept": "application/json",
            },
        )

        try:
            with urlopen(api_request, timeout=8) as response:
                response_body = response.read().decode("utf-8")
                logger.info(
                    "Open Food Facts response: barcode=%s http_status=%s body=%s",
                    barcode,
                    response.status,
                    response_body,
                )
                data = json.loads(response_body)
        except HTTPError as exc:
            error_body = exc.read().decode("utf-8", errors="replace")
            logger.warning(
                "Open Food Facts HTTP error: barcode=%s http_status=%s body=%s",
                barcode,
                exc.code,
                error_body,
            )
            if exc.code == 404:
                return Response(
                    {"found": False, "barcode": barcode},
                    status=404,
                )
            return Response(
                {"detail": "Ürün servisine ulaşılamadı."},
                status=503,
            )
        except (URLError, TimeoutError, SocketTimeout) as exc:
            logger.warning(
                "Open Food Facts request failed: barcode=%s error=%s",
                barcode,
                exc,
            )
            return Response(
                {"detail": "Ürün servisine ulaşılamadı."},
                status=503,
            )
        except (UnicodeDecodeError, json.JSONDecodeError) as exc:
            logger.warning(
                "Invalid Open Food Facts response: barcode=%s error=%s",
                barcode,
                exc,
            )
            return Response(
                {"detail": "Ürün servisinden geçersiz yanıt alındı."},
                status=502,
            )

        if not isinstance(data, dict):
            logger.warning(
                "Unexpected Open Food Facts payload: barcode=%s type=%s",
                barcode,
                type(data).__name__,
            )
            return Response(
                {"detail": "Ürün servisinden geçersiz yanıt alındı."},
                status=502,
            )

        product = data.get("product")
        if str(data.get("status")) != "1" or not isinstance(product, dict):
            return Response(
                {"found": False, "barcode": barcode},
                status=404,
            )

        quantity, unit = normalize_product_quantity(product)

        return Response(
            {
                "found": True,
                "barcode": barcode,
                "name": product.get("product_name") or "",
                "brand": product.get("brands") or "",
                "quantity": quantity,
                "unit": unit,
                "quantity_text": product.get("quantity") or "",
                "product_quantity": product.get("product_quantity"),
                "product_quantity_unit": (
                    product.get("product_quantity_unit") or ""
                ),
                "image": product.get("image_front_url"),
            }
        )
class ReceiptAnalyzeView(APIView):
    permission_classes = [IsAuthenticated]
    parser_classes = [MultiPartParser, FormParser]

    def post(self, request):
        receipt = request.FILES.get("receipt")

        if not receipt:
            return Response(
                {"detail": "Fiş görseli gönderilmedi."},
                status=400,
            )

        if receipt.size > MAX_RECEIPT_SIZE:
            return Response(
                {"detail": "Fiş görseli en fazla 10 MB olabilir."},
                status=413,
            )

        try:
            image_bytes = receipt.read()
            content_type = receipt_image_media_type(image_bytes)
            if not settings.OPENAI_API_KEY:
                raise RuntimeError("OPENAI_API_KEY yapılandırılmamış.")

            base64_image = base64.b64encode(image_bytes).decode("ascii")
            client = OpenAI(api_key=settings.OPENAI_API_KEY)
            response = client.responses.parse(
                model="gpt-4o-mini",
                text_format=ReceiptAnalysis,
                input=[
                    {
                        "role": "user",
                        "content": [
                            {
                                "type": "input_text",
                                "text": """
Bu bir market fişi görselidir.

Fişte satın alınan ürünleri tespit et.

Sadece gerçek ürün satırlarını çıkar.
Toplam, KDV, tarih, mağaza adı, ödeme tipi gibi bilgileri ürün olarak alma.

Her ürün için:
- name
- quantity
- unit

alanlarını döndür.

Fişte ürünün adedi, ağırlığı veya hacmi yazıyorsa bunu kullan.
Product quantity alanı tam sayı olduğu için kilogramı grama, litreyi
mililitreye çevir. Örneğin 0,750 KG için quantity=750 ve unit="g";
1,5 LT için quantity=1500 ve unit="ml" döndür.
Paket/adet sayısı biliniyorsa unit="adet" kullan.
Miktar veya birim güvenilir şekilde belirlenemiyorsa quantity=1 ve
unit="adet" kullan. Fiyatı hiçbir zaman miktar olarak alma.

Sadece JSON döndür.

Örnek:
{
  "products": [
    {
      "name": "Süt",
      "quantity": 1000,
      "unit": "ml"
    },
    {
      "name": "Makarna",
      "quantity": 2,
      "unit": "adet"
    }
  ]
}
""",
                            },
                            {
                                "type": "input_image",
                                "image_url": (
                                    f"data:{content_type};base64,"
                                    f"{base64_image}"
                                ),
                            },
                        ],
                    }
                ],
            )

            return Response(parse_receipt_response(response))

        except ReceiptImageError as exc:
            print(f"RECEIPT ANALYZE ERROR: {exc!r}", flush=True)
            logger.exception("Receipt image validation failed")
            return Response({"detail": str(exc)}, status=400)
        except (json.JSONDecodeError, ValidationError) as exc:
            print(f"RECEIPT ANALYZE ERROR: {exc!r}", flush=True)
            logger.exception("Receipt response parsing failed")
            return Response(
                {
                    "detail": "Fiş analiz servisinden geçersiz yanıt alındı.",
                },
                status=502,
            )

        except Exception as exc:
            print(f"RECEIPT ANALYZE ERROR: {exc!r}", flush=True)
            logger.exception("Receipt analysis failed")

            return Response(
                {
                    "detail": "Fiş analiz edilirken hata oluştu.",
                },
                status=500,
            )
