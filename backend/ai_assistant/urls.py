from django.urls import path
from .views import RecipeSuggestionView

urlpatterns = [
    path(
        'recipe/',
        RecipeSuggestionView.as_view(),
        name='recipe-suggestion'
    ),
]