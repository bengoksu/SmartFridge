from django.urls import path

from .views import (
    ShoppingItemListCreateView,
    ShoppingItemDetailView,
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
]