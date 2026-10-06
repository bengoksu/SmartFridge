import base64
import json
import logging
import os

from openai import OpenAI
from rest_framework import generics
from rest_framework.parsers import MultiPartParser, FormParser
from rest_framework.permissions import IsAuthenticated
from rest_framework.response import Response
from rest_framework.views import APIView

from households.models import FamilyActivity

from .models import ShoppingItem
from .serializers import ShoppingItemSerializer


logger = logging.getLogger(__name__)


class ShoppingItemListCreateView(generics.ListCreateAPIView):
    serializer_class = ShoppingItemSerializer
    permission_classes = [IsAuthenticated]

    def get_queryset(self):
        household = self.request.user.households.first()

        if household:
            return ShoppingItem.objects.filter(
                household=household
            ).order_by('-created_at')

        return ShoppingItem.objects.filter(
            added_by=self.request.user,
            household__isnull=True
        ).order_by('-created_at')

    def perform_create(self, serializer):
        household = self.request.user.households.first()

        shopping_item = serializer.save(
            added_by=self.request.user,
            household=household
        )

        if household:
            try:
                FamilyActivity.objects.create(
                    household=household,
                    user=self.request.user,
                    action_type='shopping_item_added',
                    message=(
                        f'{self.request.user.get_username()} '
                        f'alışveriş listesine {shopping_item.name} ekledi.'
                    ),
                )
            except Exception:
                logger.exception(
                    'Shopping item %s was created, but its family activity could not be saved.',
                    shopping_item.pk,
                )


class ShoppingItemDetailView(generics.RetrieveUpdateDestroyAPIView):
    serializer_class = ShoppingItemSerializer
    permission_classes = [IsAuthenticated]

    def get_queryset(self):
        household = self.request.user.households.first()

        if household:
            return ShoppingItem.objects.filter(
                household=household
            )

        return ShoppingItem.objects.filter(
            added_by=self.request.user,
            household__isnull=True
        )

    def perform_update(self, serializer):
        was_completed = serializer.instance.is_completed
        shopping_item = serializer.save()

        if (
            not was_completed
            and shopping_item.is_completed
            and shopping_item.household
        ):
            try:
                FamilyActivity.objects.create(
                    household=shopping_item.household,
                    user=self.request.user,
                    action_type='shopping_item_completed',
                    message=(
                        f'{self.request.user.get_username()} '
                        f'{shopping_item.name} ürününü aldı.'
                    ),
                )
            except Exception:
                logger.exception(
                    'Shopping item %s was completed, but its family activity could not be saved.',
                    shopping_item.pk,
                )

    def perform_destroy(self, instance):
        item_id = instance.pk
        item_name = instance.name
        household = instance.household

        instance.delete()

        if household:
            try:
                FamilyActivity.objects.create(
                    household=household,
                    user=self.request.user,
                    action_type='shopping_item_deleted',
                    message=(
                        f'{self.request.user.get_username()} '
                        f'alışveriş listesinden {item_name} sildi.'
                    ),
                )
            except Exception:
                logger.exception(
                    'Shopping item %s was deleted, but its family activity could not be saved.',
                    item_id,
                )


class AnalyzeShoppingListView(APIView):
    permission_classes = [IsAuthenticated]
    parser_classes = [MultiPartParser, FormParser]

    max_file_size = 20 * 1024 * 1024
    analysis_prompt = """
Bu dosya bir alışveriş listesi, diyet listesi veya alınması gereken ürünleri
içeren bir listedir.

Dosyada satın alınması gereken gıda ve market ürünlerini tespit et.

Kurallar:
- Yemek isimlerini değil, satın alınacak ürünleri çıkar.
- Gün, öğün, tarih, saat, kalori, porsiyon, açıklama ve başlıkları ürün olarak alma.
- Aynı ürün birden fazla kez geçiyorsa yalnızca bir kez döndür.
- Ürün isimlerini sade ve anlaşılır hale getir.
- Sadece geçerli JSON döndür; Markdown kod bloğu kullanma.

Format tam olarak şöyle olsun:
{
  "items": [
    {"name": "Süt"},
    {"name": "Yumurta"}
  ]
}
"""

    def post(self, request):
        list_image = request.FILES.get("list_image")
        list_pdf = request.FILES.get("list_pdf")

        if not list_image and not list_pdf:
            return Response(
                {"detail": "Liste görseli veya PDF dosyası gönderilmedi."},
                status=400,
            )

        # İki alan birden gönderilirse geriye dönük uyumluluk için görseli seç.
        selected_file = list_image or list_pdf
        is_pdf = list_image is None

        if selected_file.size > self.max_file_size:
            return Response(
                {"detail": "Liste dosyası en fazla 20 MB olabilir."},
                status=413,
            )

        file_bytes = selected_file.read()
        if is_pdf and not file_bytes.startswith(b"%PDF-"):
            return Response(
                {"detail": "Seçilen dosya geçerli bir PDF değil."},
                status=400,
            )

        encoded_file = base64.b64encode(file_bytes).decode("ascii")
        if is_pdf:
            file_content = {
                "type": "input_file",
                "filename": os.path.basename(selected_file.name) or "liste.pdf",
                "file_data": f"data:application/pdf;base64,{encoded_file}",
            }
        else:
            content_type = selected_file.content_type or "image/jpeg"
            file_content = {
                "type": "input_image",
                "image_url": f"data:{content_type};base64,{encoded_file}",
            }

        try:
            client = OpenAI(
                api_key=os.getenv("OPENAI_API_KEY"),
            )
            response = client.responses.create(
                model="gpt-4o-mini",
                input=[
                    {
                        "role": "user",
                        "content": [
                            {
                                "type": "input_text",
                                "text": self.analysis_prompt,
                            },
                            file_content,
                        ],
                    }
                ],
            )

            raw_text = response.output_text.strip()

            if raw_text.startswith("```json"):
                raw_text = raw_text.removeprefix("```json")
                raw_text = raw_text.removesuffix("```").strip()
            elif raw_text.startswith("```"):
                raw_text = raw_text.removeprefix("```")
                raw_text = raw_text.removesuffix("```").strip()

            result = self._normalize_result(json.loads(raw_text))

            return Response(result)

        except json.JSONDecodeError:
            return Response(
                {
                    "detail": "Liste sonucu işlenemedi.",
                },
                status=500,
            )

        except Exception as exc:
            print("SHOPPING LIST ANALYZE ERROR:", repr(exc))

            return Response(
                {
                    "detail": "Liste analiz edilirken hata oluştu.",
                },
                status=500,
            )

    @staticmethod
    def _normalize_result(result):
        if not isinstance(result, dict) or not isinstance(result.get("items"), list):
            raise ValueError("Model yanıtında items listesi bulunamadı.")

        items = []
        seen_names = set()
        for item in result["items"]:
            if not isinstance(item, dict):
                continue
            name = " ".join(str(item.get("name", "")).split())
            normalized_name = name.casefold()
            if not name or normalized_name in seen_names:
                continue
            seen_names.add(normalized_name)
            items.append({"name": name})

        return {"items": items}
