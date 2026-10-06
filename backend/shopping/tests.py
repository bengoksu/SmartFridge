import base64
from types import SimpleNamespace
from unittest.mock import MagicMock, patch

from django.core.files.uploadedfile import SimpleUploadedFile
from django.test import SimpleTestCase
from rest_framework.test import APIRequestFactory, force_authenticate

from .views import (
    AnalyzeShoppingListView,
    ShoppingItemDetailView,
    ShoppingItemListCreateView,
)


class ShoppingItemActivityTests(SimpleTestCase):
    @patch('shopping.views.FamilyActivity.objects.create')
    def test_creates_activity_when_shopping_item_is_added(self, create_activity):
        household = MagicMock()
        user = MagicMock()
        user.households.first.return_value = household
        user.get_username.return_value = 'ayse'
        serializer = MagicMock()
        serializer.save.return_value = SimpleNamespace(pk=42, name='Süt')
        view = ShoppingItemListCreateView()
        view.request = MagicMock(user=user)

        view.perform_create(serializer)

        serializer.save.assert_called_once_with(
            added_by=user,
            household=household,
        )
        create_activity.assert_called_once_with(
            household=household,
            user=user,
            action_type='shopping_item_added',
            message='ayse alışveriş listesine Süt ekledi.',
        )

    @patch('shopping.views.FamilyActivity.objects.create')
    def test_item_without_household_does_not_create_activity(self, create_activity):
        user = MagicMock()
        user.households.first.return_value = None
        serializer = MagicMock()
        serializer.save.return_value = SimpleNamespace(pk=42, name='Süt')
        view = ShoppingItemListCreateView()
        view.request = MagicMock(user=user)

        view.perform_create(serializer)

        serializer.save.assert_called_once_with(added_by=user, household=None)
        create_activity.assert_not_called()

    @patch('shopping.views.logger.exception')
    @patch('shopping.views.FamilyActivity.objects.create')
    def test_activity_error_does_not_break_item_creation(
        self,
        create_activity,
        log_exception,
    ):
        create_activity.side_effect = RuntimeError('activity unavailable')
        user = MagicMock()
        user.households.first.return_value = MagicMock()
        serializer = MagicMock()
        serializer.save.return_value = SimpleNamespace(pk=42, name='Süt')
        view = ShoppingItemListCreateView()
        view.request = MagicMock(user=user)

        view.perform_create(serializer)

        serializer.save.assert_called_once()
        log_exception.assert_called_once()

    @patch('shopping.views.FamilyActivity.objects.create')
    def test_creates_activity_when_shopping_item_is_deleted(self, create_activity):
        household = MagicMock()
        item = MagicMock(pk=42, household=household)
        item.name = 'Süt'
        user = MagicMock()
        user.get_username.return_value = 'ayse'
        view = ShoppingItemDetailView()
        view.request = MagicMock(user=user)

        view.perform_destroy(item)

        item.delete.assert_called_once_with()
        create_activity.assert_called_once_with(
            household=household,
            user=user,
            action_type='shopping_item_deleted',
            message='ayse alışveriş listesinden Süt sildi.',
        )

    @patch('shopping.views.FamilyActivity.objects.create')
    def test_deleted_item_without_household_skips_activity(self, create_activity):
        item = MagicMock(pk=42, household=None)
        item.name = 'Yumurta'
        view = ShoppingItemDetailView()
        view.request = MagicMock(user=MagicMock())

        view.perform_destroy(item)

        item.delete.assert_called_once_with()
        create_activity.assert_not_called()

    @patch('shopping.views.logger.exception')
    @patch('shopping.views.FamilyActivity.objects.create')
    def test_activity_error_does_not_break_item_deletion(
        self,
        create_activity,
        log_exception,
    ):
        create_activity.side_effect = RuntimeError('activity unavailable')
        item = MagicMock(pk=42, household=MagicMock())
        item.name = 'Süt'
        view = ShoppingItemDetailView()
        view.request = MagicMock(user=MagicMock())

        view.perform_destroy(item)

        item.delete.assert_called_once_with()
        log_exception.assert_called_once()

    @patch('shopping.views.FamilyActivity.objects.create')
    def test_creates_activity_on_false_to_true_completion(self, create_activity):
        household = MagicMock()
        user = MagicMock()
        user.get_username.return_value = 'ayse'
        serializer = MagicMock()
        serializer.instance.is_completed = False
        serializer.save.return_value = SimpleNamespace(
            pk=42,
            name='Süt',
            household=household,
            is_completed=True,
        )
        view = ShoppingItemDetailView()
        view.request = MagicMock(user=user)

        view.perform_update(serializer)

        serializer.save.assert_called_once_with()
        create_activity.assert_called_once_with(
            household=household,
            user=user,
            action_type='shopping_item_completed',
            message='ayse Süt ürününü aldı.',
        )

    @patch('shopping.views.FamilyActivity.objects.create')
    def test_does_not_repeat_activity_when_item_is_already_completed(
        self,
        create_activity,
    ):
        serializer = MagicMock()
        serializer.instance.is_completed = True
        serializer.save.return_value = SimpleNamespace(
            pk=42,
            name='Süt',
            household=MagicMock(),
            is_completed=True,
        )
        view = ShoppingItemDetailView()
        view.request = MagicMock(user=MagicMock())

        view.perform_update(serializer)

        serializer.save.assert_called_once_with()
        create_activity.assert_not_called()

    @patch('shopping.views.FamilyActivity.objects.create')
    def test_completed_item_without_household_skips_activity(self, create_activity):
        serializer = MagicMock()
        serializer.instance.is_completed = False
        serializer.save.return_value = SimpleNamespace(
            pk=42,
            name='Süt',
            household=None,
            is_completed=True,
        )
        view = ShoppingItemDetailView()
        view.request = MagicMock(user=MagicMock())

        view.perform_update(serializer)

        serializer.save.assert_called_once_with()
        create_activity.assert_not_called()

    @patch('shopping.views.logger.exception')
    @patch('shopping.views.FamilyActivity.objects.create')
    def test_activity_error_does_not_break_item_completion(
        self,
        create_activity,
        log_exception,
    ):
        create_activity.side_effect = RuntimeError('activity unavailable')
        serializer = MagicMock()
        serializer.instance.is_completed = False
        serializer.save.return_value = SimpleNamespace(
            pk=42,
            name='Süt',
            household=MagicMock(),
            is_completed=True,
        )
        view = ShoppingItemDetailView()
        view.request = MagicMock(user=MagicMock())

        view.perform_update(serializer)

        serializer.save.assert_called_once_with()
        log_exception.assert_called_once()


class AnalyzeShoppingListViewTests(SimpleTestCase):
    def setUp(self):
        self.factory = APIRequestFactory()
        self.view = AnalyzeShoppingListView.as_view()
        self.user = SimpleNamespace(is_authenticated=True)

    def post(self, data):
        request = self.factory.post('/api/shopping/analyze-list/', data)
        force_authenticate(request, user=self.user)
        return self.view(request)

    def test_requires_an_image_or_pdf(self):
        response = self.post({})

        self.assertEqual(response.status_code, 400)
        self.assertIn('PDF', response.data['detail'])

    def test_rejects_invalid_pdf_content(self):
        response = self.post({
            'list_pdf': SimpleUploadedFile(
                'liste.pdf',
                b'not-a-pdf',
                content_type='application/pdf',
            ),
        })

        self.assertEqual(response.status_code, 400)
        self.assertIn('geçerli bir PDF', response.data['detail'])

    @patch('shopping.views.OpenAI')
    def test_analyzes_pdf_and_deduplicates_items(self, openai_mock):
        openai_mock.return_value.responses.create.return_value = SimpleNamespace(
            output_text='{"items":[{"name":" Süt "},{"name":"süt"},{"name":"Muz"}]}'
        )

        response = self.post({
            'list_pdf': SimpleUploadedFile(
                'diyet-listesi.pdf',
                b'%PDF-1.4 test',
                content_type='application/pdf',
            ),
        })

        self.assertEqual(response.status_code, 200)
        self.assertEqual(response.data, {
            'items': [{'name': 'Süt'}, {'name': 'Muz'}],
        })
        content = openai_mock.return_value.responses.create.call_args.kwargs[
            'input'
        ][0]['content']
        pdf_input = content[1]
        self.assertEqual(pdf_input['type'], 'input_file')
        self.assertEqual(pdf_input['filename'], 'diyet-listesi.pdf')
        self.assertTrue(pdf_input['file_data'].startswith(
            'data:application/pdf;base64,'
        ))
        encoded = pdf_input['file_data'].split(',', 1)[1]
        self.assertEqual(base64.b64decode(encoded), b'%PDF-1.4 test')

    @patch('shopping.views.OpenAI')
    def test_prefers_image_when_both_files_are_sent(self, openai_mock):
        openai_mock.return_value.responses.create.return_value = SimpleNamespace(
            output_text='{"items":[]}'
        )

        response = self.post({
            'list_image': SimpleUploadedFile(
                'liste.jpg',
                b'image-bytes',
                content_type='image/jpeg',
            ),
            'list_pdf': SimpleUploadedFile(
                'liste.pdf',
                b'%PDF-1.4 test',
                content_type='application/pdf',
            ),
        })

        self.assertEqual(response.status_code, 200)
        content = openai_mock.return_value.responses.create.call_args.kwargs[
            'input'
        ][0]['content']
        self.assertEqual(content[1]['type'], 'input_image')
