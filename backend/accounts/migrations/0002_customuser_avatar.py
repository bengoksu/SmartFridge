from django.db import migrations, models
import django.core.validators


class Migration(migrations.Migration):
    dependencies = [
        ('accounts', '0001_initial'),
    ]

    operations = [
        migrations.AddField(
            model_name='customuser',
            name='avatar',
            field=models.ImageField(
                blank=True,
                null=True,
                upload_to='avatars/',
                validators=[
                    django.core.validators.FileExtensionValidator(
                        ['jpg', 'jpeg', 'png', 'webp']
                    )
                ],
            ),
        ),
    ]
