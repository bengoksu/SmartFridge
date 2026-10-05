from rest_framework import generics
from rest_framework.permissions import IsAuthenticated

from .models import Product
from .serializers import ProductSerializer
import json
from urllib.request import Request, urlopen
from urllib.error import URLError, HTTPError

from rest_framework.views import APIView
from rest_framework.response import Response
from rest_framework.permissions import IsAuthenticated


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
        url = (
            f"https://world.openfoodfacts.org/api/v2/product/"
            f"{barcode}.json"
            f"?fields=code,product_name,brands,quantity,image_front_url"
        )

        api_request = Request(
            url,
            headers={
                "User-Agent": "SmartFridge/1.0 - barcode-scan"
            },
        )

        try:
            with urlopen(api_request, timeout=8) as response:
                data = json.loads(response.read().decode("utf-8"))

        except (HTTPError, URLError, TimeoutError):
            return Response(
                {"detail": "Ürün servisine ulaşılamadı."},
                status=503,
            )

        if data.get("status") != 1:
            return Response(
                {
                    "found": False,
                    "barcode": barcode,
                },
                status=404,
            )

        product = data.get("product", {})

        return Response(
            {
                "found": True,
                "barcode": barcode,
                "name": product.get("product_name") or "",
                "brand": product.get("brands") or "",
                "quantity": product.get("quantity") or "",
                "image": product.get("image_front_url"),
            }
        )