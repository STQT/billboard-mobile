import { useState } from 'react';
import {
  Box,
  Typography,
  Paper,
  TextField,
  Button,
  Grid,
  Card,
  CardContent,
} from '@mui/material';
import { Refresh as RefreshIcon } from '@mui/icons-material';

export default function Playlists() {
  const [vehicleId, setVehicleId] = useState('');

  const handleRegenerate = () => {
    console.log('Regenerate playlist for vehicle:', vehicleId);
  };

  return (
    <Box>
      <Typography variant="h4" gutterBottom>
        Плейлисты
      </Typography>

      <Paper sx={{ p: 3, mb: 3 }}>
        <Typography variant="h6" gutterBottom>
          Управление плейлистами
        </Typography>
        <Grid container spacing={2} alignItems="center">
          <Grid item xs={12} md={6}>
            <TextField
              fullWidth
              label="ID автомобиля"
              type="number"
              value={vehicleId}
              onChange={(e) => setVehicleId(e.target.value)}
              helperText="Введите ID автомобиля для генерации плейлиста"
            />
          </Grid>
          <Grid item xs={12} md={6}>
            <Button
              fullWidth
              variant="contained"
              startIcon={<RefreshIcon />}
              onClick={handleRegenerate}
              sx={{ height: 56 }}
            >
              Сгенерировать плейлист
            </Button>
          </Grid>
        </Grid>
      </Paper>

      <Card>
        <CardContent>
          <Typography variant="h6" gutterBottom>
            Информация о плейлистах
          </Typography>
          <Typography variant="body2" color="textSecondary">
            • Плейлисты генерируются автоматически на 24 часа
          </Typography>
          <Typography variant="body2" color="textSecondary" sx={{ mt: 1 }}>
            • Контрактные видео вставляются с заданной частотой
          </Typography>
          <Typography variant="body2" color="textSecondary" sx={{ mt: 1 }}>
            • Филлеры заполняют оставшееся время
          </Typography>
          <Typography variant="body2" color="textSecondary" sx={{ mt: 1 }}>
            • Плейлист обновляется автоматически при истечении срока
          </Typography>
        </CardContent>
      </Card>
    </Box>
  );
}
