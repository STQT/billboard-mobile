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

type ViewMode = 'vehicle' | 'tariff';

export default function Playlists() {
  const [viewMode, setViewMode] = useState<ViewMode>('tariff');
  const [vehicles, setVehicles] = useState<Vehicle[]>([]);
  const [selectedVehicleId, setSelectedVehicleId] = useState<number | ''>('');
  const [selectedTariff, setSelectedTariff] = useState<string>('standard');
  const [playlist, setPlaylist] = useState<Playlist | null>(null);
  const [videosMap, setVideosMap] = useState<Record<number, Video>>({});
  const [loadingVehicles, setLoadingVehicles] = useState(true);
  const [loadingPlaylist, setLoadingPlaylist] = useState(false);
  const [regenerating, setRegenerating] = useState(false);
  const { enqueueSnackbar } = useSnackbar();

  const tariffs: Array<{ value: string; label: string }> = [
    { value: 'standard', label: 'Стандарт' },
    { value: 'comfort', label: 'Комфорт' },
    { value: 'business', label: 'Бизнес' },
    { value: 'premium', label: 'Премиум' },
  ];

  useEffect(() => {
    loadVehicles();
    loadVideos();
  }, []);

  useEffect(() => {
    if (viewMode === 'vehicle' && selectedVehicleId) {
      loadPlaylistByVehicle(selectedVehicleId as number);
    } else if (viewMode === 'tariff') {
      loadPlaylistByTariff(selectedTariff);
    } else {
      setPlaylist(null);
    }
  }, [selectedVehicleId, selectedTariff, viewMode]);

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

  const loadPlaylistByVehicle = async (vehicleId: number) => {
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

  const loadPlaylistByTariff = async (tariff: string) => {
    try {
      setLoadingPlaylist(true);
      const res = await playlistsApi.getByTariff(tariff);
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
    try {
      setRegenerating(true);
      let res;
      if (viewMode === 'vehicle' && selectedVehicleId) {
        res = await playlistsApi.regenerate(selectedVehicleId as number, 24);
      } else if (viewMode === 'tariff') {
        res = await playlistsApi.regenerateByTariff(selectedTariff, 24);
      } else {
        return;
      }
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
        Плейлисты
      </Typography>

      <Paper sx={{ p: 3, mb: 3 }}>
        <Typography variant="h6" gutterBottom>
          Режим просмотра
        </Typography>
        <Grid container spacing={2} alignItems="center">
          <Grid item xs={12} md={3}>
            <FormControl fullWidth>
              <InputLabel>Режим</InputLabel>
              <Select
                value={viewMode}
                label="Режим"
                onChange={(e) => setViewMode(e.target.value as ViewMode)}
              >
                <MenuItem value="tariff">По тарифу</MenuItem>
                <MenuItem value="vehicle">По автомобилю</MenuItem>
              </Select>
            </FormControl>
          </Grid>
          <Grid item xs={12} md={viewMode === 'tariff' ? 6 : 6}>
            {viewMode === 'tariff' ? (
              <FormControl fullWidth>
                <InputLabel>Тариф</InputLabel>
                <Select
                  value={selectedTariff}
                  label="Тариф"
                  onChange={(e) => setSelectedTariff(e.target.value)}
                >
                  {tariffs.map((t) => (
                    <MenuItem key={t.value} value={t.value}>
                      {t.label}
                    </MenuItem>
                  ))}
                </Select>
              </FormControl>
            ) : (
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
            )}
          </Grid>
          <Grid item xs={12} md={3}>
            <Button
              fullWidth
              variant="contained"
              startIcon={regenerating ? <CircularProgress size={20} /> : <RefreshIcon />}
              onClick={handleRegenerate}
              disabled={
                regenerating ||
                (viewMode === 'vehicle' && !selectedVehicleId) ||
                (viewMode === 'tariff' && !selectedTariff)
              }
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

      {((viewMode === 'vehicle' && selectedVehicleId && !loadingVehicles && vehicles.length > 0) ||
        (viewMode === 'tariff' && selectedTariff)) && (
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
                    {viewMode === 'tariff' ? (
                      <>Плейлист по тарифу: {tariffs.find(t => t.value === playlist.tariff)?.label || playlist.tariff}</>
                    ) : (
                      <>Плейлист: {selectedVehicle?.car_number} ({selectedVehicle?.tariff})</>
                    )}
                  </Typography>
                  {playlist.vehicle_id === null && (
                    <Chip label="Общий плейлист" size="small" color="primary" sx={{ ml: 1 }} />
                  )}
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
              Плейлист не найден. Нажмите «Сгенерировать новый плейлист».
            </Alert>
          )}
        </>
      )}

      {viewMode === 'vehicle' && !loadingVehicles && vehicles.length === 0 && (
        <Alert severity="info">
          Сначала добавьте автомобили в разделе «Автомобили».
        </Alert>
      )}

      <Card sx={{ mt: 3 }}>
        <CardContent>
          <Typography variant="h6" gutterBottom>
            Как устроены плейлисты
          </Typography>
          <Typography variant="body2" color="textSecondary">
            • Плейлисты создаются на 24 часа по тарифу (standard, comfort, business, premium).
          </Typography>
          <Typography variant="body2" color="textSecondary" sx={{ mt: 1 }}>
            • Все автомобили одного тарифа используют один общий плейлист.
          </Typography>
          <Typography variant="body2" color="textSecondary" sx={{ mt: 1 }}>
            • Сначала проверяются контрактные видео для тарифа, затем заполняются филлерами.
          </Typography>
          <Typography variant="body2" color="textSecondary" sx={{ mt: 1 }}>
            • Если нет контрактных видео, плейлист заполняется только филлерами в разброс.
          </Typography>
          <Typography variant="body2" color="textSecondary" sx={{ mt: 1 }}>
            • После истечения срока приложение запрашивает новый плейлист автоматически.
          </Typography>
        </CardContent>
      </Card>
    </Box>
  );
}
