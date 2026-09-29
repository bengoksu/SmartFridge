from django.test import SimpleTestCase

from .serializers import ProductSerializer


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
