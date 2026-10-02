from django.urls import path

from .views import HouseholdCreateView, JoinHouseholdView,  MyHouseholdView

urlpatterns = [
    path('create/', HouseholdCreateView.as_view(), name='household-create'),
    path('join/', JoinHouseholdView.as_view(), name='household-join'),
      path('my/', MyHouseholdView.as_view(), name='household-my'),
]