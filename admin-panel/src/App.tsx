import { Routes, Route, Navigate } from 'react-router-dom';
import Layout from './components/Layout';
import Dashboard from './pages/Dashboard';
import Vehicles from './pages/Vehicles';
import Videos from './pages/Videos';
import Analytics from './pages/Analytics';
import Playlists from './pages/Playlists';

function App() {
  return (
    <Layout>
      <Routes>
        <Route path="/" element={<Navigate to="/dashboard" replace />} />
        <Route path="/dashboard" element={<Dashboard />} />
        <Route path="/vehicles" element={<Vehicles />} />
        <Route path="/videos" element={<Videos />} />
        <Route path="/analytics" element={<Analytics />} />
        <Route path="/playlists" element={<Playlists />} />
      </Routes>
    </Layout>
  );
}

export default App;
