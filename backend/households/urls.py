from django.urls import path

from .views import HouseholdCreateView, JoinHouseholdView

urlpatterns = [
    path('create/', HouseholdCreateView.as_view(), name='household-create'),
    path('join/', JoinHouseholdView.as_view(), name='household-join'),
]