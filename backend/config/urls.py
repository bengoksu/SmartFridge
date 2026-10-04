from django.contrib import admin
from django.conf import settings
from django.conf.urls.static import static
from django.urls import path, include

urlpatterns = [
    path('admin/', admin.site.urls),
    path('api/accounts/', include('accounts.urls')),
    path('api/households/', include('households.urls')),
    path('api/fridge/', include('fridge.urls')),
    path('api/ai/', include('ai_assistant.urls')),
        path('api/shopping/', include('shopping.urls')),
]

if settings.DEBUG:
    urlpatterns += static(settings.MEDIA_URL, document_root=settings.MEDIA_ROOT)
