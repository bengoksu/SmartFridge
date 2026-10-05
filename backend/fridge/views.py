import json
import logging
import re
from decimal import Decimal, InvalidOperation, ROUND_HALF_UP
from socket import timeout as SocketTimeout
from urllib.error import HTTPError, URLError
from urllib.parse import quote
from urllib.request import Request, urlopen

from rest_framework import generics
from rest_framework.permissions import IsAuthenticated
from rest_framework.response import Response
from rest_framework.views import APIView

from .models import Product
from .serializers import ProductSerializer


logger = logging.getLogger(__name__)


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
            ).order_by('expiry_date')

        return Product.objects.filter(
            owner=self.request.user
        ).order_by('expiry_date')

    def perform_create(self, serializer):
        household = self.request.user.households.first()

        serializer.save(
            owner=self.request.user,
            household=household
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
