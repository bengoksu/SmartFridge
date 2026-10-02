from django.conf import settings
from django.db import models
import uuid


class Household(models.Model):
    name = models.CharField(max_length=100)
    owner = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.CASCADE,
        related_name='owned_households'
    )
    members = models.ManyToManyField(
        settings.AUTH_USER_MODEL,
        related_name='households',
        blank=True
    )
    invite_code = models.UUIDField(
    default=uuid.uuid4,
    unique=True,
    editable=False
)
    created_at = models.DateTimeField(auto_now_add=True)

    def __str__(self):
        return self.name

    