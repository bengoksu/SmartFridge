from rest_framework.permissions import IsAuthenticated
from rest_framework.response import Response
from rest_framework.views import APIView

from fridge.models import Product
from .services import get_recipe_suggestion


class RecipeSuggestionView(APIView):
    permission_classes = [IsAuthenticated]

    def post(self, request):
        household = request.user.households.first()

        if household:
            products = Product.objects.filter(
                household=household
            )
        else:
            products = Product.objects.filter(
                owner=request.user
            )

        product_data = list(
            products.values(
                'name',
                'quantity',
                'unit',
                'expiry_date',
            )
        )

        if not product_data:
            return Response(
                {
                    'detail': 'Buzdolabında tarif önermek için ürün bulunamadı.'
                },
                status=400
            )

        previous_recipes = request.data.get('previous_recipes', [])
        if not isinstance(previous_recipes, list):
            previous_recipes = []

        meal_type = request.data.get('meal_type', 'any')
        if meal_type not in {
            'any', 'main', 'menu', 'breakfast', 'snack', 'dessert'
        }:
            meal_type = 'any'

        meal_time = request.data.get('meal_time', 'any')
        if meal_time not in {'any', 'breakfast', 'lunch', 'dinner'}:
            meal_time = 'any'

        product_names = {product['name'] for product in product_data}
        preferred_product = request.data.get('preferred_product')
        if preferred_product not in product_names:
            preferred_product = None

        max_minutes = request.data.get('max_minutes')
        if max_minutes not in (15, 30, 45):
            max_minutes = None

        recipe = get_recipe_suggestion(
            product_data,
            meal_type=meal_type,
            meal_time=meal_time,
            preferred_product=preferred_product,
            servings=request.data.get('servings', 2),
            max_minutes=max_minutes,
            previous_recipes=[
                str(recipe)[:200]
                for recipe in previous_recipes[-5:]
            ],
        )

        return Response(
            {
                'recipe': recipe
            }
        )
