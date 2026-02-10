import { useEffect, useState } from 'react';
import {
  Box,
  Typography,
  Paper,
  Button,
  Grid,
  Card,
  CardContent,
  FormControl,
  InputLabel,
  Select,
  MenuItem,
  List,
  ListItem,
  ListItemText,
  Chip,
  CircularProgress,
  Alert,
} from '@mui/material';
import { Refresh as RefreshIcon, PlaylistPlay as PlaylistIcon } from '@mui/icons-material';
import { useSnackbar } from 'notistack';
import { vehiclesApi, playlistsApi, videosApi } from '../services/api';
import type { Vehicle, Playlist, Video } from '../types';

const formatDate = (dateStr: string) => {
  try {
    const d = new Date(dateStr);
    return d.toLocaleString('ru-RU');
  } catch {
    return dateStr;
  }
};

export default function Playlists() {
  const [vehicles, setVehicles] = useState<Vehicle[]>([]);
  const [selectedVehicleId, setSelectedVehicleId] = useState<number | ''>('');
  const [playlist, setPlaylist] = useState<Playlist | null>(null);
  const [videosMap, setVideosMap] = useState<Record<number, Video>>({});
  const [loadingVehicles, setLoadingVehicles] = useState(true);
  const [loadingPlaylist, setLoadingPlaylist] = useState(false);
  const [regenerating, setRegenerating] = useState(false);
  const { enqueueSnackbar } = useSnackbar();

  useEffect(() => {
    loadVehicles();
    loadVideos();
  }, []);

  useEffect(() => {
    if (selectedVehicleId) {
      loadPlaylist(selectedVehicleId as number);
    } else {
      setPlaylist(null);
    }
  }, [selectedVehicleId]);

  const loadVehicles = async () => {
    try {
      setLoadingVehicles(true);
      const res = await vehiclesApi.getAll();
      setVehicles(res.data);
      if (res.data.length > 0 && !selectedVehicleId) {
        setSelectedVehicleId(res.data[0].id);
      }
    } catch (e) {
      enqueueSnackbar('Ошибка загрузки автомобилей', { variant: 'error' });
    } finally {
      setLoadingVehicles(false);
    }
  };

  const loadVideos = async () => {
    try {
      const res = await videosApi.getAll();
      const map: Record<number, Video> = {};
      res.data.forEach((v) => { map[v.id] = v; });
      setVideosMap(map);
    } catch {
      // не блокируем интерфейс
    }
  };

  const loadPlaylist = async (vehicleId: number) => {
    try {
      setLoadingPlaylist(true);
      const res = await playlistsApi.getByVehicle(vehicleId);
      setPlaylist(res.data);
    } catch (e: any) {
      const msg = e.response?.data?.detail || 'Ошибка загрузки плейлиста';
      enqueueSnackbar(msg, { variant: 'error' });
      setPlaylist(null);
    } finally {
      setLoadingPlaylist(false);
    }
  };

  const handleRegenerate = async () => {
    if (!selectedVehicleId) return;
    try {
      setRegenerating(true);
      const res = await playlistsApi.regenerate(selectedVehicleId as number, 24);
      setPlaylist(res.data);
      enqueueSnackbar('Плейлист пересоздан', { variant: 'success' });
    } catch (e: any) {
      const msg = e.response?.data?.detail || 'Ошибка генерации плейлиста';
      enqueueSnackbar(msg, { variant: 'error' });
    } finally {
      setRegenerating(false);
    }
  };

  const selectedVehicle = vehicles.find((v) => v.id === selectedVehicleId);

  return (
    <Box>
      <Typography variant="h4" gutterBottom>
        Плейлисты автомобилей
      </Typography>

      <Paper sx={{ p: 3, mb: 3 }}>
        <Typography variant="h6" gutterBottom>
          Выберите автомобиль
        </Typography>
        <Grid container spacing={2} alignItems="center">
          <Grid item xs={12} md={6}>
            <FormControl fullWidth disabled={loadingVehicles}>
              <InputLabel>Автомобиль</InputLabel>
              <Select
                value={selectedVehicleId}
                label="Автомобиль"
                onChange={(e) => setSelectedVehicleId(e.target.value as number | '')}
              >
                {vehicles.map((v) => (
                  <MenuItem key={v.id} value={v.id}>
                    {v.car_number} — {v.login} ({v.tariff})
                  </MenuItem>
                ))}
                {vehicles.length === 0 && !loadingVehicles && (
                  <MenuItem disabled>Нет автомобилей</MenuItem>
                )}
              </Select>
            </FormControl>
          </Grid>
          <Grid item xs={12} md={6}>
            <Button
              fullWidth
              variant="contained"
              startIcon={regenerating ? <CircularProgress size={20} /> : <RefreshIcon />}
              onClick={handleRegenerate}
              disabled={!selectedVehicleId || regenerating}
              sx={{ height: 56 }}
            >
              Сгенерировать новый плейлист
            </Button>
          </Grid>
        </Grid>
      </Paper>

      {loadingVehicles && (
        <Box display="flex" justifyContent="center" py={3}>
          <CircularProgress />
        </Box>
      )}

      {!loadingVehicles && vehicles.length === 0 && (
        <Alert severity="info">
          Сначала добавьте автомобили в разделе «Автомобили».
        </Alert>
      )}

      {selectedVehicleId && !loadingVehicles && vehicles.length > 0 && (
        <>
          {loadingPlaylist ? (
            <Box display="flex" justifyContent="center" py={4}>
              <CircularProgress />
            </Box>
          ) : playlist ? (
            <Card>
              <CardContent>
                <Box display="flex" alignItems="center" gap={1} mb={2}>
                  <PlaylistIcon color="primary" />
                  <Typography variant="h6">
                    Плейлист: {selectedVehicle?.car_number} ({selectedVehicle?.tariff})
                  </Typography>
                </Box>
                <Grid container spacing={2}>
                  <Grid item xs={12} sm={6} md={3}>
                    <Typography variant="body2" color="textSecondary">
                      Действует с
                    </Typography>
                    <Typography variant="body1">{formatDate(playlist.valid_from)}</Typography>
                  </Grid>
                  <Grid item xs={12} sm={6} md={3}>
                    <Typography variant="body2" color="textSecondary">
                      Действует до
                    </Typography>
                    <Typography variant="body1">{formatDate(playlist.valid_until)}</Typography>
                  </Grid>
                  <Grid item xs={12} sm={6} md={3}>
                    <Typography variant="body2" color="textSecondary">
                      Видео в плейлисте
                    </Typography>
                    <Typography variant="body1">
                      <Chip label={playlist.video_sequence.length} size="small" />
                    </Typography>
                  </Grid>
                </Grid>
                <Typography variant="subtitle2" sx={{ mt: 2, mb: 1 }}>
                  Порядок воспроизведения (ID видео):
                </Typography>
                <Paper variant="outlined" sx={{ maxHeight: 320, overflow: 'auto' }}>
                  <List dense>
                    {playlist.video_sequence.slice(0, 100).map((videoId, index) => (
                      <ListItem key={`${index}-${videoId}`}>
                        <ListItemText
                          primary={`${index + 1}. ${videosMap[videoId]?.title || `Видео #${videoId}`}`}
                          secondary={`ID: ${videoId}`}
                        />
                      </ListItem>
                    ))}
                    {playlist.video_sequence.length > 100 && (
                      <ListItem>
                        <ListItemText
                          secondary={`... и ещё ${playlist.video_sequence.length - 100} видео`}
                        />
                      </ListItem>
                    )}
                  </List>
                </Paper>
              </CardContent>
            </Card>
          ) : (
            <Alert severity="warning">
              Плейлист для выбранного автомобиля не найден. Нажмите «Сгенерировать новый плейлист».
            </Alert>
          )}
        </>
      )}

      <Card sx={{ mt: 3 }}>
        <CardContent>
          <Typography variant="h6" gutterBottom>
            Как устроены плейлисты
          </Typography>
          <Typography variant="body2" color="textSecondary">
            • Плейлисты создаются на 24 часа по тарифу автомобиля.
          </Typography>
          <Typography variant="body2" color="textSecondary" sx={{ mt: 1 }}>
            • Контрактные видео вставляются с заданной частотой (показов в час).
          </Typography>
          <Typography variant="body2" color="textSecondary" sx={{ mt: 1 }}>
            • Оставшееся время заполняется филлерами.
          </Typography>
          <Typography variant="body2" color="textSecondary" sx={{ mt: 1 }}>
            • После истечения срока приложение запрашивает новый плейлист автоматически.
          </Typography>
        </CardContent>
      </Card>
    </Box>
  );
}
