from rest_framework import generics
from rest_framework.permissions import IsAuthenticated

from .models import ShoppingItem
from .serializers import ShoppingItemSerializer


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