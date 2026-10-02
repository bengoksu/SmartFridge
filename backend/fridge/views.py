from rest_framework import generics
from rest_framework.permissions import IsAuthenticated

from .models import Product
from .serializers import ProductSerializer


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