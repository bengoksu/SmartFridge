from rest_framework import generics
from rest_framework.permissions import IsAuthenticated

from .models import ShoppingItem
from .serializers import ShoppingItemSerializer
import base64
import json
import os

from openai import OpenAI


from rest_framework.permissions import IsAuthenticated
from rest_framework.parsers import MultiPartParser, FormParser
from rest_framework.response import Response
from rest_framework.views import APIView


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

        serializer.save(
            added_by=self.request.user,
            household=household
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
class AnalyzeShoppingListView(APIView):
    permission_classes = [IsAuthenticated]
    parser_classes = [MultiPartParser, FormParser]

    def post(self, request):
        list_image = request.FILES.get("list_image")

        if not list_image:
            return Response(
                {"detail": "Liste görseli gönderilmedi."},
                status=400,
            )

        image_bytes = list_image.read()
        base64_image = base64.b64encode(image_bytes).decode("utf-8")

        content_type = list_image.content_type or "image/jpeg"

        client = OpenAI(
            api_key=os.getenv("OPENAI_API_KEY"),
        )

        try:
            response = client.responses.create(
                model="gpt-4o-mini",
                input=[
                    {
                        "role": "user",
                        "content": [
                            {
                                "type": "input_text",
                                "text": """
Bu görsel bir alışveriş listesi, diyet listesi
veya alınması gereken ürünleri içeren bir listedir.

Görselde satın alınması gereken gıda ve market ürünlerini tespit et.

Kurallar:
- Yemek isimlerini değil, satın alınacak ürünleri çıkar.
- Gün, öğün, kalori, saat, açıklama gibi bilgileri alma.
- Aynı ürün birden fazla kez geçiyorsa tek ürün olarak döndür.
- Ürün isimlerini sade ve anlaşılır hale getir.
- Sadece JSON döndür.

Format tam olarak şöyle olsun:

{
  "items": [
    {
      "name": "Süt"
    },
    {
      "name": "Yumurta"
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

            raw_text = response.output_text.strip()

            if raw_text.startswith("```json"):
                raw_text = raw_text.removeprefix("```json")
                raw_text = raw_text.removesuffix("```").strip()
            elif raw_text.startswith("```"):
                raw_text = raw_text.removeprefix("```")
                raw_text = raw_text.removesuffix("```").strip()

            result = json.loads(raw_text)

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