import base64
from types import SimpleNamespace
from unittest.mock import patch

from django.core.files.uploadedfile import SimpleUploadedFile
from django.test import SimpleTestCase
from rest_framework.test import APIRequestFactory, force_authenticate

from .views import AnalyzeShoppingListView


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
