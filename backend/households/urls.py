from django.urls import path

from .views import (
    HouseholdCreateView,
    JoinHouseholdView,
    LeaveHouseholdView,
    MyHouseholdView,
)

urlpatterns = [
    path('create/', HouseholdCreateView.as_view(), name='household-create'),
    path('join/', JoinHouseholdView.as_view(), name='household-join'),
    path('leave/', LeaveHouseholdView.as_view(), name='household-leave'),
    path('my/', MyHouseholdView.as_view(), name='household-my'),
]
