from rest_framework import generics, status
from rest_framework.permissions import IsAuthenticated
from rest_framework.response import Response
from rest_framework.views import APIView

from .models import Household
from .serializers import HouseholdSerializer, JoinHouseholdSerializer


class HouseholdCreateView(generics.CreateAPIView):
    serializer_class = HouseholdSerializer
    permission_classes = [IsAuthenticated]

    def perform_create(self, serializer):
        household = serializer.save(owner=self.request.user)
        household.members.add(self.request.user)


class JoinHouseholdView(APIView):
    permission_classes = [IsAuthenticated]

    def post(self, request):
        serializer = JoinHouseholdSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)

        invite_code = serializer.validated_data['invite_code']

        try:
            household = Household.objects.get(invite_code=invite_code)
        except Household.DoesNotExist:
            return Response(
                {'detail': 'Geçersiz davet kodu.'},
                status=status.HTTP_404_NOT_FOUND
            )

        if household.members.filter(id=request.user.id).exists():
            return Response(
                {'detail': 'Zaten bu aileye üyesiniz.'},
                status=status.HTTP_400_BAD_REQUEST
            )

        household.members.add(request.user)

        return Response(
            {
                'detail': 'Aileye başarıyla katıldınız.',
                'household_id': household.id,
                'household_name': household.name,
            },
            status=status.HTTP_200_OK
        )
class MyHouseholdView(generics.ListAPIView):
    serializer_class = HouseholdSerializer
    permission_classes = [IsAuthenticated]

def get_queryset(self):
    return Household.objects.filter(
        members=self.request.user
    ).distinct()
 