from django.db import models

# Create your models here.
from django.conf import settings
from django.db import models


class Product(models.Model):
    name = models.CharField(max_length=100)
    quantity = models.PositiveIntegerField(default=1)
    unit = models.CharField(max_length=30, blank=True)
    expiry_date = models.DateField(null=True, blank=True)

    owner = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.CASCADE,
        related_name='fridge_products'
    )

    created_at = models.DateTimeField(auto_now_add=True)

    def __str__(self):
        return self.name