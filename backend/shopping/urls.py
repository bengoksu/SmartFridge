from django.urls import path

from .views import (
    ShoppingItemListCreateView,
    ShoppingItemDetailView,
    AnalyzeShoppingListView,
)

urlpatterns = [
    path(
        'items/',
        ShoppingItemListCreateView.as_view(),
        name='shopping-item-list-create',
    ),

    path(
        'items/<int:pk>/',
        ShoppingItemDetailView.as_view(),
        name='shopping-item-detail',
    ),
    path(
    'analyze-list/',
    AnalyzeShoppingListView.as_view(),
    name='analyze-shopping-list',
),
]