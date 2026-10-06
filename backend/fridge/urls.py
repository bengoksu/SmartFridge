from django.urls import path

from .views import (
    BarcodeLookupView,
    ProductListCreateView,
    ProductDetailView,
    ReceiptAnalyzeView,
)

urlpatterns = [
    path(
        'products/',
        ProductListCreateView.as_view(),
        name='product-list-create',
    ),
    path(
        'products/<int:pk>/',
        ProductDetailView.as_view(),
        name='product-detail',
    ),
    path(
        'barcode/<str:barcode>/',
        BarcodeLookupView.as_view(),
        name='barcode-lookup',
    ),
    path(
    'receipt/analyze/',
    ReceiptAnalyzeView.as_view(),
    name='receipt-analyze',
),
]
