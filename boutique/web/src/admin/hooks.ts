import { useCallback, useEffect, useState } from 'react';
import { api, ApiError } from '../api';

/** Charge une ressource admin, avec état de chargement, erreur et rechargement. */
export function useFetch<T>(url: string | null) {
  const [data, setData] = useState<T | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [loading, setLoading] = useState(false);
  const reload = useCallback(() => {
    if (!url) return;
    setLoading(true); setError(null);
    api.get<T>(url).then(setData).catch((e: ApiError) => setError(e.message)).finally(() => setLoading(false));
  }, [url]);
  useEffect(() => { reload(); }, [reload]);
  return { data, error, loading, reload, setData };
}
