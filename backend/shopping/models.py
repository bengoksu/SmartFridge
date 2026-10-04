from django.conf import settings
from django.db import models

from households.models import Household


class ShoppingItem(models.Model):
    name = models.CharField(max_length=100)

    is_completed = models.BooleanField(
        default=False
    )

    added_by = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.CASCADE,
        related_name='shopping_items'
    )

    household = models.ForeignKey(
        Household,
        on_delete=models.CASCADE,
        related_name='shopping_items',
        null=True,
        blank=True
    )

    created_at = models.DateTimeField(
        auto_now_add=True
    )

    def __str__(self):
        return self.name