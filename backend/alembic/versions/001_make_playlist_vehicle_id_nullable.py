"""make playlist vehicle_id nullable

Revision ID: 001
Revises: 
Create Date: 2025-02-10 12:00:00.000000

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa

# revision identifiers, used by Alembic.
revision: str = '001'
down_revision: Union[str, None] = None
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    # Сделать vehicle_id nullable в таблице playlists
    op.alter_column('playlists', 'vehicle_id',
                    existing_type=sa.Integer(),
                    nullable=True)
    
    # Создать индекс на tariff если его еще нет
    # Проверяем существование индекса через SQL
    connection = op.get_bind()
    result = connection.execute(sa.text(
        "SELECT COUNT(*) FROM pg_indexes WHERE indexname = 'ix_playlists_tariff'"
    )).scalar()
    
    if result == 0:
        op.create_index('ix_playlists_tariff', 'playlists', ['tariff'], unique=False)


def downgrade() -> None:
    # Удалить индекс
    op.drop_index('ix_playlists_tariff', table_name='playlists')
    
    # Вернуть vehicle_id как NOT NULL (но это может вызвать ошибку если есть NULL значения)
    # В реальности лучше сначала заполнить NULL значения перед downgrade
    op.alter_column('playlists', 'vehicle_id',
                    existing_type=sa.Integer(),
                    nullable=False)
