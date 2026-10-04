from rest_framework import serializers

from .models import ShoppingItem


class ShoppingItemSerializer(serializers.ModelSerializer):
    added_by_username = serializers.CharField(
        source='added_by.username',
        read_only=True
    )

    class Meta:
        model = ShoppingItem
        fields = [
            'id',
            'name',
            'is_completed',
            'added_by',
            'added_by_username',
            'household',
            'created_at',
        ]

        read_only_fields = [
            'added_by',
            'household',
            'created_at',
        ]