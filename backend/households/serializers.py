from rest_framework import serializers
from .models import Household


class HouseholdSerializer(serializers.ModelSerializer):
    owner_username = serializers.CharField(
        source='owner.username',
        read_only=True
    )

    member_usernames = serializers.SerializerMethodField()

    class Meta:
        model = Household
        fields = [
            'id',
            'name',
            'owner',
            'owner_username',
            'members',
            'member_usernames',
            'invite_code',
            'created_at',
        ]

        read_only_fields = [
            'owner',
            'members',
            'invite_code',
            'created_at',
        ]

    def get_member_usernames(self, obj):
        return list(
            obj.members.values_list('username', flat=True)
        )


class JoinHouseholdSerializer(serializers.Serializer):
    invite_code = serializers.UUIDField()