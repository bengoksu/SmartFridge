from datetime import datetime, timezone
from types import SimpleNamespace
from unittest.mock import MagicMock, patch

from django.test import SimpleTestCase
from django.urls import resolve, reverse
from rest_framework.permissions import IsAuthenticated

from .serializers import FamilyActivitySerializer
from .views import FamilyActivityListView


class FamilyActivityEndpointTests(SimpleTestCase):
    def test_route_resolves_to_activity_list_view(self):
        url = reverse('family-activity-list')

        self.assertEqual(url, '/api/households/activities/')
        self.assertIs(resolve(url).func.view_class, FamilyActivityListView)

    def test_endpoint_requires_authentication(self):
        self.assertEqual(FamilyActivityListView.permission_classes, [IsAuthenticated])

    @patch('households.views.FamilyActivity.objects.none')
    def test_returns_empty_queryset_without_household(self, none):
        view = FamilyActivityListView()
        user = MagicMock()
        user.households.first.return_value = None
        view.request = MagicMock(user=user)

        result = view.get_queryset()

        self.assertIs(result, none.return_value)
        none.assert_called_once_with()

    @patch('households.views.FamilyActivity.objects.filter')
    def test_filters_and_orders_activities_by_users_household(self, filter_activities):
        household = MagicMock()
        user = MagicMock()
        user.households.first.return_value = household
        ordered_queryset = filter_activities.return_value.select_related.return_value.order_by.return_value
        view = FamilyActivityListView()
        view.request = MagicMock(user=user)

        result = view.get_queryset()

        filter_activities.assert_called_once_with(household=household)
        filter_activities.return_value.select_related.assert_called_once_with('user')
        filter_activities.return_value.select_related.return_value.order_by.assert_called_once_with(
            '-created_at'
        )
        self.assertIs(result, ordered_queryset)

    def test_serializer_includes_username(self):
        activity_user = MagicMock()
        activity_user.get_username.return_value = 'ayse'
        activity = SimpleNamespace(
            id=7,
            action_type='product_added',
            message='ayse buzdolabına Süt ekledi.',
            created_at=datetime(2026, 10, 6, 12, 30, tzinfo=timezone.utc),
            user=activity_user,
        )

        data = FamilyActivitySerializer(activity).data

        self.assertEqual(data['id'], 7)
        self.assertEqual(data['user'], {'username': 'ayse'})
