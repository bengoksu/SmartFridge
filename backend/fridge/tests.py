import json
from django.test import SimpleTestCase
from django.urls import resolve, reverse
from rest_framework.test import APIRequestFactory, force_authenticate
from unittest.mock import MagicMock, patch

from .serializers import ProductSerializer
from .views import BarcodeLookupView, normalize_product_quantity


class ProductSerializerTests(SimpleTestCase):
    def test_accepts_turkish_characters_in_name_and_unit(self):
        serializer = ProductSerializer(
            data={
                'name': 'Çilekli süt ve öğütülmüş şeker',
                'quantity': 2,
                'unit': 'ölçü',
                'expiry_date': '2026-10-10',
            }
        )

        self.assertTrue(serializer.is_valid(), serializer.errors)
        self.assertEqual(
            serializer.validated_data['name'],
            'Çilekli süt ve öğütülmüş şeker',
        )
        self.assertEqual(serializer.validated_data['unit'], 'ölçü')


class BarcodeLookupViewTests(SimpleTestCase):
    def setUp(self):
        self.factory = APIRequestFactory()

    def _get(self, barcode):
        request = self.factory.get(f'/api/fridge/barcode/{barcode}/')
        user = MagicMock()
        user.is_authenticated = True
        force_authenticate(request, user=user)
        return BarcodeLookupView.as_view()(request, barcode=barcode)

    @staticmethod
    def _upstream_response(payload, status=200):
        response = MagicMock()
        response.status = status
        response.read.return_value = json.dumps(payload).encode('utf-8')
        context_manager = MagicMock()
        context_manager.__enter__.return_value = response
        return context_manager

    def test_barcode_route_resolves_to_lookup_view(self):
        url = reverse('barcode-lookup', args=['3017620422003'])

        self.assertEqual(url, '/api/fridge/barcode/3017620422003/')
        self.assertIs(resolve(url).func.view_class, BarcodeLookupView)

    @patch('fridge.views.urlopen')
    def test_returns_open_food_facts_product(self, mocked_urlopen):
        mocked_urlopen.return_value = self._upstream_response({
            'status': 1,
            'product': {
                'product_name': 'Nutella',
                'brands': 'Nutella, Ferrero',
                'quantity': '400 g',
                'product_quantity': 400,
                'product_quantity_unit': 'g',
                'image_front_url': 'https://example.com/nutella.jpg',
            },
        })

        response = self._get('3017620422003')

        self.assertEqual(response.status_code, 200)
        self.assertTrue(response.data['found'])
        self.assertEqual(response.data['name'], 'Nutella')
        self.assertEqual(response.data['quantity'], 400)
        self.assertEqual(response.data['unit'], 'g')
        self.assertEqual(response.data['quantity_text'], '400 g')
        upstream_request = mocked_urlopen.call_args.args[0]
        self.assertIn('3017620422003.json', upstream_request.full_url)
        self.assertEqual(upstream_request.get_header('Accept'), 'application/json')
        self.assertTrue(upstream_request.get_header('User-agent').startswith('SmartFridge/'))

    @patch('fridge.views.urlopen')
    def test_status_zero_preserves_not_found_response(self, mocked_urlopen):
        mocked_urlopen.return_value = self._upstream_response({
            'status': 0,
            'status_verbose': 'product not found',
        })

        response = self._get('1234567890123')

        self.assertEqual(response.status_code, 404)
        self.assertEqual(
            response.data,
            {'found': False, 'barcode': '1234567890123'},
        )

    def test_rejects_invalid_barcode_without_upstream_request(self):
        with patch('fridge.views.urlopen') as mocked_urlopen:
            response = self._get('not-a-barcode')

        self.assertEqual(response.status_code, 400)
        mocked_urlopen.assert_not_called()


class ProductQuantityNormalizationTests(SimpleTestCase):
    def test_converts_litres_to_integer_millilitres(self):
        self.assertEqual(
            normalize_product_quantity({
                'product_quantity': 1.5,
                'product_quantity_unit': 'L',
            }),
            (1500, 'ml'),
        )

    def test_keeps_millilitres_and_grams(self):
        self.assertEqual(
            normalize_product_quantity({
                'product_quantity': 500,
                'product_quantity_unit': 'ml',
            }),
            (500, 'ml'),
        )
        self.assertEqual(
            normalize_product_quantity({'quantity': '400 g'}),
            (400, 'g'),
        )

    def test_converts_kilograms_to_integer_grams(self):
        self.assertEqual(
            normalize_product_quantity({'quantity': '1 kg'}),
            (1000, 'g'),
        )
