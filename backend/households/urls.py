from django.urls import path

from .views import (
    FamilyActivityListView,
    HouseholdCreateView,
    JoinHouseholdView,
    LeaveHouseholdView,
    MyHouseholdView,
)

urlpatterns = [
    path(
        'activities/',
        FamilyActivityListView.as_view(),
        name='family-activity-list',
    ),
    path('create/', HouseholdCreateView.as_view(), name='household-create'),
    path('join/', JoinHouseholdView.as_view(), name='household-join'),
    path('leave/', LeaveHouseholdView.as_view(), name='household-leave'),
    path('my/', MyHouseholdView.as_view(), name='household-my'),
]
