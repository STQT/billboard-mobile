import { useEffect, useState } from 'react';
import {
  Box,
  Button,
  Paper,
  Table,
  TableBody,
  TableCell,
  TableContainer,
  TableHead,
  TableRow,
  Typography,
  IconButton,
  Chip,
  Dialog,
  DialogTitle,
  DialogContent,
  DialogActions,
  TextField,
  MenuItem,
  FormControl,
  InputLabel,
  Select,
  OutlinedInput,
} from '@mui/material';
import {
  Add as AddIcon,
  Edit as EditIcon,
  Delete as DeleteIcon,
  Refresh as RefreshIcon,
  Upload as UploadIcon,
} from '@mui/icons-material';
import { useSnackbar } from 'notistack';
import { videosApi } from '../services/api';
import type { Video } from '../types';

const videoTypes = [
  { value: 'filler', label: 'Филлер' },
  { value: 'contract', label: 'Контрактное' },
];

const tariffs = ['standard', 'comfort', 'business', 'premium'];

export default function Videos() {
  const [videos, setVideos] = useState<Video[]>([]);
  const [loading, setLoading] = useState(true);
  const [dialogOpen, setDialogOpen] = useState(false);
  const [selectedFile, setSelectedFile] = useState<File | null>(null);
  const { enqueueSnackbar } = useSnackbar();

  const [formData, setFormData] = useState({
    title: '',
    video_type: 'filler',
    plays_per_hour: 1,
    tariffs: ['standard'],
    priority: 0,
  });

  useEffect(() => {
    loadVideos();
  }, []);

  const loadVideos = async () => {
    try {
      const response = await videosApi.getAll();
      setVideos(response.data);
    } catch (error) {
      enqueueSnackbar('Ошибка загрузки видео', { variant: 'error' });
    } finally {
      setLoading(false);
    }
  };

  const handleOpenDialog = () => {
    setFormData({
      title: '',
      video_type: 'filler',
      plays_per_hour: 1,
      tariffs: ['standard'],
      priority: 0,
    });
    setSelectedFile(null);
    setDialogOpen(true);
  };

  const handleCloseDialog = () => {
    setDialogOpen(false);
  };

  const handleFileChange = (event: React.ChangeEvent<HTMLInputElement>) => {
    if (event.target.files && event.target.files[0]) {
      setSelectedFile(event.target.files[0]);
    }
  };

  const handleSubmit = async () => {
    if (!selectedFile) {
      enqueueSnackbar('Выберите видеофайл', { variant: 'warning' });
      return;
    }

    try {
      const formDataToSend = new FormData();
      formDataToSend.append('file', selectedFile);
      formDataToSend.append('title', formData.title);
      formDataToSend.append('video_type', formData.video_type);
      formDataToSend.append('tariffs', JSON.stringify(formData.tariffs));
      formDataToSend.append('priority', formData.priority.toString());
      
      if (formData.video_type === 'contract') {
        formDataToSend.append('plays_per_hour', formData.plays_per_hour.toString());
      }

      await videosApi.create(formDataToSend);
      enqueueSnackbar('Видео загружено', { variant: 'success' });
      handleCloseDialog();
      loadVideos();
    } catch (error) {
      enqueueSnackbar('Ошибка загрузки видео', { variant: 'error' });
    }
  };

  const handleDelete = async (id: number) => {
    if (window.confirm('Вы уверены? Видео будет удалено.')) {
      try {
        await videosApi.delete(id);
        enqueueSnackbar('Видео удалено', { variant: 'success' });
        loadVideos();
      } catch (error) {
        enqueueSnackbar('Ошибка удаления', { variant: 'error' });
      }
    }
  };

  const formatFileSize = (bytes?: number) => {
    if (!bytes) return '-';
    const mb = bytes / (1024 * 1024);
    return `${mb.toFixed(2)} MB`;
  };

  const formatDuration = (seconds?: number) => {
    if (!seconds) return '-';
    const mins = Math.floor(seconds / 60);
    const secs = Math.floor(seconds % 60);
    return `${mins}:${secs.toString().padStart(2, '0')}`;
  };

  return (
    <Box>
      <Box display="flex" justifyContent="space-between" alignItems="center" mb={3}>
        <Typography variant="h4">Видео</Typography>
        <Box>
          <IconButton onClick={loadVideos} sx={{ mr: 1 }}>
            <RefreshIcon />
          </IconButton>
          <Button
            variant="contained"
            startIcon={<AddIcon />}
            onClick={handleOpenDialog}
          >
            Загрузить видео
          </Button>
        </Box>
      </Box>

      <TableContainer component={Paper}>
        <Table>
          <TableHead>
            <TableRow>
              <TableCell>ID</TableCell>
              <TableCell>Название</TableCell>
              <TableCell>Тип</TableCell>
              <TableCell>Размер</TableCell>
              <TableCell>Длительность</TableCell>
              <TableCell>Показы/час</TableCell>
              <TableCell>Тарифы</TableCell>
              <TableCell>Приоритет</TableCell>
              <TableCell>Статус</TableCell>
              <TableCell align="right">Действия</TableCell>
            </TableRow>
          </TableHead>
          <TableBody>
            {videos.length === 0 ? (
              <TableRow>
                <TableCell colSpan={10} align="center">
                  Нет видео. Загрузите первое видео.
                </TableCell>
              </TableRow>
            ) : (
              videos.map((video) => (
                <TableRow key={video.id}>
                  <TableCell>{video.id}</TableCell>
                  <TableCell>{video.title}</TableCell>
                  <TableCell>
                    <Chip
                      label={videoTypes.find((t) => t.value === video.video_type)?.label}
                      color={video.video_type === 'contract' ? 'primary' : 'default'}
                      size="small"
                    />
                  </TableCell>
                  <TableCell>{formatFileSize(video.file_size)}</TableCell>
                  <TableCell>{formatDuration(video.duration)}</TableCell>
                  <TableCell>
                    {video.video_type === 'contract' ? video.plays_per_hour : '-'}
                  </TableCell>
                  <TableCell>{video.tariffs}</TableCell>
                  <TableCell>{video.priority}</TableCell>
                  <TableCell>
                    <Chip
                      label={video.is_active ? 'Активно' : 'Неактивно'}
                      color={video.is_active ? 'success' : 'default'}
                      size="small"
                    />
                  </TableCell>
                  <TableCell align="right">
                    <IconButton size="small" onClick={() => handleDelete(video.id)}>
                      <DeleteIcon />
                    </IconButton>
                  </TableCell>
                </TableRow>
              ))
            )}
          </TableBody>
        </Table>
      </TableContainer>

      <Dialog open={dialogOpen} onClose={handleCloseDialog} maxWidth="sm" fullWidth>
        <DialogTitle>Загрузить видео</DialogTitle>
        <DialogContent>
          <TextField
            fullWidth
            label="Название"
            value={formData.title}
            onChange={(e) => setFormData({ ...formData, title: e.target.value })}
            margin="normal"
          />
          
          <TextField
            fullWidth
            select
            label="Тип видео"
            value={formData.video_type}
            onChange={(e) => setFormData({ ...formData, video_type: e.target.value })}
            margin="normal"
          >
            {videoTypes.map((option) => (
              <MenuItem key={option.value} value={option.value}>
                {option.label}
              </MenuItem>
            ))}
          </TextField>

          {formData.video_type === 'contract' && (
            <TextField
              fullWidth
              type="number"
              label="Показов в час"
              value={formData.plays_per_hour}
              onChange={(e) =>
                setFormData({ ...formData, plays_per_hour: parseInt(e.target.value) })
              }
              margin="normal"
            />
          )}

          <FormControl fullWidth margin="normal">
            <InputLabel>Тарифы</InputLabel>
            <Select
              multiple
              value={formData.tariffs}
              onChange={(e) =>
                setFormData({ ...formData, tariffs: e.target.value as string[] })
              }
              input={<OutlinedInput label="Тарифы" />}
            >
              {tariffs.map((tariff) => (
                <MenuItem key={tariff} value={tariff}>
                  {tariff}
                </MenuItem>
              ))}
            </Select>
          </FormControl>

          <TextField
            fullWidth
            type="number"
            label="Приоритет"
            value={formData.priority}
            onChange={(e) => setFormData({ ...formData, priority: parseInt(e.target.value) })}
            margin="normal"
          />

          <Button
            fullWidth
            variant="outlined"
            component="label"
            startIcon={<UploadIcon />}
            sx={{ mt: 2 }}
          >
            {selectedFile ? selectedFile.name : 'Выбрать видеофайл'}
            <input type="file" hidden accept="video/*" onChange={handleFileChange} />
          </Button>
        </DialogContent>
        <DialogActions>
          <Button onClick={handleCloseDialog}>Отмена</Button>
          <Button onClick={handleSubmit} variant="contained">
            Загрузить
          </Button>
        </DialogActions>
      </Dialog>
    </Box>
  );
}
