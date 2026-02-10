import { useEffect, useState, useMemo } from 'react';
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
  Table,
  TableBody,
  TableCell,
  TableContainer,
  TableHead,
  TableRow,
  Tooltip,
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

  // Получить список филлеров для выбранного тарифа
  const fillers = useMemo(() => {
    const currentTariff = viewMode === 'tariff' ? selectedTariff : selectedVehicle?.tariff;
    if (!currentTariff) return [];
    
    return Object.values(videosMap).filter(
      (v) => v.video_type === 'filler' && v.is_active && v.tariffs.includes(currentTariff)
    );
  }, [videosMap, selectedTariff, selectedVehicle, viewMode]);

  // Вычислить временную шкалу плейлиста на основе контрактных видео
  const timeline = useMemo(() => {
    if (!playlist || !playlist.contract_videos.length) return [];

    return playlist.contract_videos.map((cv) => ({
      videoId: cv.video_id,
      video: videosMap[cv.video_id],
      startTime: cv.start_time,
      endTime: cv.end_time,
      duration: cv.duration,
      frequency: cv.frequency,
      isContract: true,
    }));
  }, [playlist, videosMap]);

  const formatTime = (seconds: number) => {
    const mins = Math.floor(seconds / 60);
    const secs = Math.floor(seconds % 60);
    return `${mins}:${secs.toString().padStart(2, '0')}`;
  };

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
                      Контрактные видео
                    </Typography>
                    <Typography variant="body1">
                      <Chip label={playlist.contract_videos.length} size="small" color="primary" />
                    </Typography>
                  </Grid>
                  <Grid item xs={12} sm={6} md={3}>
                    <Typography variant="body2" color="textSecondary">
                      Филлеры
                    </Typography>
                    <Typography variant="body1">
                      <Chip label={playlist.filler_videos.length} size="small" color="warning" />
                    </Typography>
                  </Grid>
                </Grid>
                <Typography variant="subtitle2" sx={{ mt: 3, mb: 1 }}>
                  Временная шкала воспроизведения (0:00 - 60:00)
                </Typography>
                <Paper variant="outlined" sx={{ p: 2, mb: 3 }}>
                  <Box sx={{ position: 'relative', height: 120, bgcolor: '#f5f5f5', borderRadius: 1 }}>
                    {timeline.map((item, idx) => {
                      const widthPercent = (item.duration / 3600) * 100;
                      const leftPercent = (item.startTime / 3600) * 100;
                      
                      return (
                        <Tooltip
                          key={`${item.videoId}-${idx}`}
                          title={
                            <Box>
                              <Typography variant="body2" fontWeight="bold">
                                {item.video?.title || `Видео #${item.videoId}`}
                              </Typography>
                              <Typography variant="caption">
                                {formatTime(item.startTime)} - {formatTime(item.endTime)}
                              </Typography>
                              <Typography variant="caption" display="block">
                                Длительность: {formatTime(item.duration)}
                              </Typography>
                              <Typography variant="caption" display="block">
                                Частота повторений: {item.frequency} раз
                              </Typography>
                              <Typography variant="caption" display="block">
                                Тип: Контрактное
                              </Typography>
                            </Box>
                          }
                          arrow
                        >
                          <Box
                            sx={{
                              position: 'absolute',
                              left: `${leftPercent}%`,
                              width: `${widthPercent}%`,
                              height: '100%',
                              bgcolor: '#1976d2',
                              border: '1px solid',
                              borderColor: '#1565c0',
                              cursor: 'pointer',
                              display: 'flex',
                              alignItems: 'center',
                              justifyContent: 'center',
                              fontSize: '10px',
                              color: 'white',
                              fontWeight: 'bold',
                              '&:hover': {
                                opacity: 0.8,
                                zIndex: 1,
                                transform: 'scaleY(1.1)',
                              },
                            }}
                            title={`${item.video?.title || `Видео #${item.videoId}`} (${formatTime(item.startTime)} - ${formatTime(item.endTime)})`}
                          >
                            {item.duration >= 30 && (
                              <Typography
                                variant="caption"
                                sx={{
                                  fontSize: '9px',
                                  textAlign: 'center',
                                  lineHeight: 1,
                                  wordBreak: 'break-word',
                                  maxWidth: '100%',
                                  px: 0.5,
                                }}
                              >
                                #{idx + 1}
                              </Typography>
                            )}
                          </Box>
                        </Tooltip>
                      );
                    })}
                    {/* Метки времени */}
                    {[0, 300, 600, 900, 1200, 1500, 1800, 2100, 2400, 2700, 3000, 3300, 3600].map((time) => (
                      <Box
                        key={time}
                        sx={{
                          position: 'absolute',
                          left: `${(time / 3600) * 100}%`,
                          top: 0,
                          bottom: 0,
                          width: '1px',
                          bgcolor: 'rgba(0,0,0,0.2)',
                          pointerEvents: 'none',
                        }}
                      >
                        <Typography
                          variant="caption"
                          sx={{
                            position: 'absolute',
                            top: -20,
                            left: -15,
                            fontSize: '10px',
                            color: 'text.secondary',
                          }}
                        >
                          {formatTime(time)}
                        </Typography>
                      </Box>
                    ))}
                  </Box>
                  <Box display="flex" gap={2} mt={2}>
                    <Box display="flex" alignItems="center" gap={1}>
                      <Box sx={{ width: 16, height: 16, bgcolor: '#1976d2', borderRadius: 0.5 }} />
                      <Typography variant="caption">Контрактные</Typography>
                    </Box>
                    <Box display="flex" alignItems="center" gap={1}>
                      <Box sx={{ width: 16, height: 16, bgcolor: '#ed6c02', borderRadius: 0.5 }} />
                      <Typography variant="caption">Филлеры</Typography>
                    </Box>
                  </Box>
                </Paper>

                <Typography variant="subtitle2" sx={{ mt: 2, mb: 1 }}>
                  Контрактные видео с временными метками:
                </Typography>
                <Paper variant="outlined" sx={{ maxHeight: 320, overflow: 'auto', mb: 3 }}>
                  <List dense>
                    {playlist.contract_videos.map((cv, index) => {
                      const video = videosMap[cv.video_id];
                      
                      return (
                        <ListItem key={`contract-${cv.video_id}-${index}`}>
                          <ListItemText
                            primary={
                              <Box display="flex" alignItems="center" gap={1}>
                                <span>{index + 1}. {video?.title || `Видео #${cv.video_id}`}</span>
                                <Chip label="Контракт" size="small" color="primary" />
                                {cv.frequency > 1 && (
                                  <Chip label={`×${cv.frequency}`} size="small" color="secondary" />
                                )}
                              </Box>
                            }
                            secondary={
                              <Box>
                                ID: {cv.video_id}
                                <span> • {formatTime(cv.start_time)} - {formatTime(cv.end_time)}</span>
                                <span> • Длительность: {formatTime(cv.duration)}</span>
                                {cv.frequency > 1 && (
                                  <span> • Повторений: {cv.frequency}</span>
                                )}
                                {cv.media_url && (
                                  <Typography variant="caption" display="block" sx={{ mt: 0.5 }}>
                                    <a href={cv.media_url} target="_blank" rel="noopener noreferrer">
                                      {cv.media_url}
                                    </a>
                                  </Typography>
                                )}
                              </Box>
                            }
                          />
                        </ListItem>
                      );
                    })}
                    {playlist.contract_videos.length === 0 && (
                      <ListItem>
                        <ListItemText secondary="Нет контрактных видео в плейлисте" />
                      </ListItem>
                    )}
                  </List>
                </Paper>

                <Typography variant="subtitle2" sx={{ mt: 2, mb: 1 }}>
                  Доступные филлеры (для заполнения промежутков):
                </Typography>
                <Paper variant="outlined" sx={{ maxHeight: 320, overflow: 'auto' }}>
                  <List dense>
                    {playlist.filler_videos.map((fv, index) => {
                      const video = videosMap[fv.video_id];
                      
                      return (
                        <ListItem key={`filler-${fv.video_id}-${index}`}>
                          <ListItemText
                            primary={
                              <Box display="flex" alignItems="center" gap={1}>
                                <span>{index + 1}. {video?.title || `Видео #${fv.video_id}`}</span>
                                <Chip label="Филлер" size="small" color="warning" />
                              </Box>
                            }
                            secondary={
                              <Box>
                                ID: {fv.video_id}
                                <span> • Длительность: {formatTime(fv.duration)}</span>
                                {fv.media_url && (
                                  <Typography variant="caption" display="block" sx={{ mt: 0.5 }}>
                                    <a href={fv.media_url} target="_blank" rel="noopener noreferrer">
                                      {fv.media_url}
                                    </a>
                                  </Typography>
                                )}
                              </Box>
                            }
                          />
                        </ListItem>
                      );
                    })}
                    {playlist.filler_videos.length === 0 && (
                      <ListItem>
                        <ListItemText secondary="Нет филлеров в плейлисте" />
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

      {/* Список филлеров */}
      {((viewMode === 'vehicle' && selectedVehicleId && !loadingVehicles && vehicles.length > 0) ||
        (viewMode === 'tariff' && selectedTariff)) && (
        <Card sx={{ mt: 3 }}>
          <CardContent>
            <Typography variant="h6" gutterBottom>
              Доступные филлеры для тарифа: {viewMode === 'tariff' 
                ? tariffs.find(t => t.value === selectedTariff)?.label 
                : tariffs.find(t => t.value === selectedVehicle?.tariff)?.label}
            </Typography>
            {fillers.length === 0 ? (
              <Alert severity="info" sx={{ mt: 2 }}>
                Нет активных филлеров для этого тарифа. Добавьте филлеры в разделе «Видео».
              </Alert>
            ) : (
              <TableContainer component={Paper} variant="outlined" sx={{ mt: 2 }}>
                <Table size="small">
                  <TableHead>
                    <TableRow>
                      <TableCell>ID</TableCell>
                      <TableCell>Название</TableCell>
                      <TableCell>Длительность</TableCell>
                      <TableCell>Приоритет</TableCell>
                      <TableCell>Размер</TableCell>
                    </TableRow>
                  </TableHead>
                  <TableBody>
                    {fillers.map((filler) => (
                      <TableRow key={filler.id}>
                        <TableCell>{filler.id}</TableCell>
                        <TableCell>{filler.title}</TableCell>
                        <TableCell>
                          {filler.duration ? formatTime(filler.duration) : '-'}
                        </TableCell>
                        <TableCell>{filler.priority}</TableCell>
                        <TableCell>
                          {filler.file_size
                            ? `${(filler.file_size / (1024 * 1024)).toFixed(2)} MB`
                            : '-'}
                        </TableCell>
                      </TableRow>
                    ))}
                  </TableBody>
                </Table>
              </TableContainer>
            )}
          </CardContent>
        </Card>
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
