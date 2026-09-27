from rest_framework import serializers
from .models import Household


class HouseholdSerializer(serializers.ModelSerializer):
    owner_username = serializers.CharField(
        source='owner.username',
        read_only=True
    )

    class Meta:
        model = Household
        fields = [
            'id',
            'name',
            'owner',
            'owner_username',
            'members',
            'created_at',
        ]
        read_only_fields = ['owner', 'members', 'created_at']
