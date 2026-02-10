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

  // Вычислить временную шкалу плейлиста
  const timeline = useMemo(() => {
    if (!playlist || !playlist.video_sequence.length) return [];

    const timelineItems: Array<{
      videoId: number;
      video: Video | undefined;
      startTime: number;
      endTime: number;
      duration: number;
      index: number;
    }> = [];

    let currentTime = 0;
    const maxTime = 3600; // 1 час в секундах

    playlist.video_sequence.forEach((videoId, index) => {
      const video = videosMap[videoId];
      const duration = video?.duration || 0;

      if (duration > 0 && currentTime < maxTime) {
        const endTime = Math.min(currentTime + duration, maxTime);
        timelineItems.push({
          videoId,
          video,
          startTime: currentTime,
          endTime,
          duration: endTime - currentTime,
          index,
        });
        currentTime = endTime;
      }
    });

    return timelineItems;
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
                      Видео в плейлисте
                    </Typography>
                    <Typography variant="body1">
                      <Chip label={playlist.video_sequence.length} size="small" />
                    </Typography>
                  </Grid>
                </Grid>
                <Typography variant="subtitle2" sx={{ mt: 3, mb: 1 }}>
                  Временная шкала воспроизведения (0:00 - 60:00)
                </Typography>
                <Paper variant="outlined" sx={{ p: 2, mb: 3 }}>
                  <Box sx={{ position: 'relative', height: 120, bgcolor: '#f5f5f5', borderRadius: 1 }}>
                    {timeline.map((item) => {
                      const widthPercent = (item.duration / 3600) * 100;
                      const leftPercent = (item.startTime / 3600) * 100;
                      const isContract = item.video?.video_type === 'contract';
                      
                      return (
                        <Tooltip
                          key={`${item.index}-${item.videoId}`}
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
                                Тип: {isContract ? 'Контрактное' : 'Филлер'}
                              </Typography>
                              <Typography variant="caption" display="block">
                                Позиция в плейлисте: #{item.index + 1}
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
                              bgcolor: isContract ? '#1976d2' : '#ed6c02',
                              border: '1px solid',
                              borderColor: isContract ? '#1565c0' : '#e65100',
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
                                #{item.index + 1}
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
                  Порядок воспроизведения (ID видео):
                </Typography>
                <Paper variant="outlined" sx={{ maxHeight: 320, overflow: 'auto' }}>
                  <List dense>
                    {playlist.video_sequence.slice(0, 100).map((videoId, index) => {
                      const video = videosMap[videoId];
                      // Найти соответствующий элемент временной шкалы по индексу
                      const timelineItem = timeline[index];
                      
                      return (
                        <ListItem key={`${index}-${videoId}`}>
                          <ListItemText
                            primary={
                              <Box display="flex" alignItems="center" gap={1}>
                                <span>{index + 1}. {video?.title || `Видео #${videoId}`}</span>
                                {video?.video_type === 'contract' && (
                                  <Chip label="Контракт" size="small" color="primary" />
                                )}
                                {video?.video_type === 'filler' && (
                                  <Chip label="Филлер" size="small" color="warning" />
                                )}
                              </Box>
                            }
                            secondary={
                              <Box>
                                ID: {videoId}
                                {timelineItem && (
                                  <span> • {formatTime(timelineItem.startTime)} - {formatTime(timelineItem.endTime)}</span>
                                )}
                                {video?.duration && (
                                  <span> • Длительность: {formatTime(video.duration)}</span>
                                )}
                              </Box>
                            }
                          />
                        </ListItem>
                      );
                    })}
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
