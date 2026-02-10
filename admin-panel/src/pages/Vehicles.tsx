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
} from '@mui/material';
import {
  Add as AddIcon,
  Edit as EditIcon,
  Delete as DeleteIcon,
  Refresh as RefreshIcon,
} from '@mui/icons-material';
import { useSnackbar } from 'notistack';
import { vehiclesApi } from '../services/api';
import type { Vehicle } from '../types';

const tariffs = [
  { value: 'standard', label: 'Стандарт' },
  { value: 'comfort', label: 'Комфорт' },
  { value: 'business', label: 'Бизнес' },
  { value: 'premium', label: 'Премиум' },
];

export default function Vehicles() {
  const [vehicles, setVehicles] = useState<Vehicle[]>([]);
  const [loading, setLoading] = useState(true);
  const [dialogOpen, setDialogOpen] = useState(false);
  const [editingVehicle, setEditingVehicle] = useState<Partial<Vehicle> | null>(null);
  const { enqueueSnackbar } = useSnackbar();

  const [formData, setFormData] = useState({
    login: '',
    password: '',
    car_number: '',
    tariff: 'standard',
    driver_name: '',
    phone: '',
  });

  useEffect(() => {
    loadVehicles();
  }, []);

  const loadVehicles = async () => {
    try {
      setLoading(true);
      const response = await vehiclesApi.getAll();
      setVehicles(response.data);
      if (response.data.length === 0) {
        enqueueSnackbar('Нет автомобилей. Добавьте первый автомобиль.', { variant: 'info' });
      }
    } catch (error: any) {
      console.error('Error loading vehicles:', error);
      const message = error.response?.data?.detail || 'Ошибка загрузки автомобилей';
      enqueueSnackbar(message, { variant: 'error' });
    } finally {
      setLoading(false);
    }
  };

  const handleOpenDialog = (vehicle?: Vehicle) => {
    if (vehicle) {
      setEditingVehicle(vehicle);
      setFormData({
        login: vehicle.login,
        password: '',
        car_number: vehicle.car_number,
        tariff: vehicle.tariff,
        driver_name: vehicle.driver_name || '',
        phone: vehicle.phone || '',
      });
    } else {
      setEditingVehicle(null);
      setFormData({
        login: '',
        password: '',
        car_number: '',
        tariff: 'standard',
        driver_name: '',
        phone: '',
      });
    }
    setDialogOpen(true);
  };

  const handleCloseDialog = () => {
    setDialogOpen(false);
    setEditingVehicle(null);
  };

  const handleSubmit = async () => {
    try {
      if (editingVehicle && editingVehicle.id) {
        // При обновлении отправляем только заполненные поля, пароль опционален
        const updateData: any = {
          login: formData.login,
          car_number: formData.car_number,
          tariff: formData.tariff as 'standard' | 'comfort' | 'business' | 'premium',
          driver_name: formData.driver_name || null,
          phone: formData.phone || null,
        };
        // Добавить пароль только если он указан
        if (formData.password && formData.password.trim()) {
          updateData.password = formData.password;
        }
        await vehiclesApi.update(editingVehicle.id, updateData);
        enqueueSnackbar('Автомобиль обновлен', { variant: 'success' });
      } else {
        // При создании пароль обязателен
        if (!formData.password || !formData.password.trim()) {
          enqueueSnackbar('Пароль обязателен для нового автомобиля', { variant: 'warning' });
          return;
        }
        await vehiclesApi.create({
          ...formData,
          tariff: formData.tariff as 'standard' | 'comfort' | 'business' | 'premium',
        });
        enqueueSnackbar('Автомобиль создан', { variant: 'success' });
      }
      handleCloseDialog();
      loadVehicles();
    } catch (error: any) {
      console.error('Error saving vehicle:', error);
      const message = error.response?.data?.detail || 'Ошибка сохранения';
      enqueueSnackbar(message, { variant: 'error' });
    }
  };

  const handleDelete = async (id: number) => {
    if (window.confirm('Вы уверены, что хотите удалить этот автомобиль?')) {
      try {
        await vehiclesApi.delete(id);
        enqueueSnackbar('Автомобиль удален', { variant: 'success' });
        loadVehicles();
      } catch (error: any) {
        console.error('Error deleting vehicle:', error);
        const message = error.response?.data?.detail || 'Ошибка удаления';
        enqueueSnackbar(message, { variant: 'error' });
      }
    }
  };

  return (
    <Box>
      <Box display="flex" justifyContent="space-between" alignItems="center" mb={3}>
        <Typography variant="h4">Автомобили</Typography>
        <Box>
          <IconButton onClick={loadVehicles} sx={{ mr: 1 }}>
            <RefreshIcon />
          </IconButton>
          <Button
            variant="contained"
            startIcon={<AddIcon />}
            onClick={() => handleOpenDialog()}
          >
            Добавить автомобиль
          </Button>
        </Box>
      </Box>

      <TableContainer component={Paper}>
        <Table>
          <TableHead>
            <TableRow>
              <TableCell>ID</TableCell>
              <TableCell>Логин</TableCell>
              <TableCell>Номер авто</TableCell>
              <TableCell>Тариф</TableCell>
              <TableCell>Водитель</TableCell>
              <TableCell>Телефон</TableCell>
              <TableCell>Статус</TableCell>
              <TableCell align="right">Действия</TableCell>
            </TableRow>
          </TableHead>
          <TableBody>
            {loading ? (
              <TableRow>
                <TableCell colSpan={8} align="center">
                  Загрузка...
                </TableCell>
              </TableRow>
            ) : vehicles.length === 0 ? (
              <TableRow>
                <TableCell colSpan={8} align="center">
                  Нет данных. Добавьте первый автомобиль.
                </TableCell>
              </TableRow>
            ) : (
              vehicles.map((vehicle) => (
                <TableRow key={vehicle.id}>
                  <TableCell>{vehicle.id}</TableCell>
                  <TableCell>{vehicle.login}</TableCell>
                  <TableCell>{vehicle.car_number}</TableCell>
                  <TableCell>
                    {tariffs.find((t) => t.value === vehicle.tariff)?.label}
                  </TableCell>
                  <TableCell>{vehicle.driver_name || '-'}</TableCell>
                  <TableCell>{vehicle.phone || '-'}</TableCell>
                  <TableCell>
                    <Chip
                      label={vehicle.is_active ? 'Активен' : 'Неактивен'}
                      color={vehicle.is_active ? 'success' : 'default'}
                      size="small"
                    />
                  </TableCell>
                  <TableCell align="right">
                    <IconButton
                      size="small"
                      onClick={() => handleOpenDialog(vehicle)}
                    >
                      <EditIcon />
                    </IconButton>
                    <IconButton
                      size="small"
                      onClick={() => handleDelete(vehicle.id)}
                    >
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
        <DialogTitle>
          {editingVehicle ? 'Редактировать автомобиль' : 'Добавить автомобиль'}
        </DialogTitle>
        <DialogContent>
          <TextField
            fullWidth
            label="Логин"
            value={formData.login}
            onChange={(e) => setFormData({ ...formData, login: e.target.value })}
            margin="normal"
            disabled={!!editingVehicle}
          />
          {!editingVehicle ? (
            <TextField
              fullWidth
              label="Пароль"
              type="password"
              value={formData.password}
              onChange={(e) => setFormData({ ...formData, password: e.target.value })}
              margin="normal"
              required
            />
          ) : (
            <TextField
              fullWidth
              label="Новый пароль (оставьте пустым чтобы не менять)"
              type="password"
              value={formData.password}
              onChange={(e) => setFormData({ ...formData, password: e.target.value })}
              margin="normal"
              helperText="Оставьте пустым, чтобы не менять текущий пароль"
            />
          )}
          <TextField
            fullWidth
            label="Номер автомобиля"
            value={formData.car_number}
            onChange={(e) => setFormData({ ...formData, car_number: e.target.value })}
            margin="normal"
          />
          <TextField
            fullWidth
            select
            label="Тариф"
            value={formData.tariff}
            onChange={(e) => setFormData({ ...formData, tariff: e.target.value })}
            margin="normal"
          >
            {tariffs.map((option) => (
              <MenuItem key={option.value} value={option.value}>
                {option.label}
              </MenuItem>
            ))}
          </TextField>
          <TextField
            fullWidth
            label="Имя водителя"
            value={formData.driver_name}
            onChange={(e) => setFormData({ ...formData, driver_name: e.target.value })}
            margin="normal"
          />
          <TextField
            fullWidth
            label="Телефон"
            value={formData.phone}
            onChange={(e) => setFormData({ ...formData, phone: e.target.value })}
            margin="normal"
          />
        </DialogContent>
        <DialogActions>
          <Button onClick={handleCloseDialog}>Отмена</Button>
          <Button onClick={handleSubmit} variant="contained">
            Сохранить
          </Button>
        </DialogActions>
      </Dialog>
    </Box>
  );
}
