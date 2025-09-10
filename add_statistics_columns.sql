-- Добавление колонок статистики в таблицу profiles
-- Выполните этот скрипт в Supabase SQL Editor

-- Сначала проверим существование таблицы profiles
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'profiles') THEN
        -- Создаем таблицу profiles если она не существует
        CREATE TABLE profiles (
            id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
            full_name TEXT,
            phone TEXT,
            avatar_url TEXT,
            birth_date DATE,
            gender TEXT,
            city TEXT,
            role TEXT DEFAULT 'client',
            created_at TIMESTAMP WITH TIME ZONE DEFAULT now(),
            updated_at TIMESTAMP WITH TIME ZONE DEFAULT now()
        );
        
        -- Включаем RLS
        ALTER TABLE profiles ENABLE ROW LEVEL SECURITY;
        
        -- Создаем политики доступа
        CREATE POLICY "Users can view own profile" ON profiles FOR SELECT USING (auth.uid() = id);
        CREATE POLICY "Users can insert own profile" ON profiles FOR INSERT WITH CHECK (auth.uid() = id);
        CREATE POLICY "Users can update own profile" ON profiles FOR UPDATE USING (auth.uid() = id);
    END IF;
END
$$;

-- Добавляем колонки статистики
ALTER TABLE profiles 
ADD COLUMN IF NOT EXISTS today_earnings DECIMAL(10,2) DEFAULT 0,
ADD COLUMN IF NOT EXISTS today_trips INTEGER DEFAULT 0,
ADD COLUMN IF NOT EXISTS total_earnings DECIMAL(10,2) DEFAULT 0,
ADD COLUMN IF NOT EXISTS total_trips INTEGER DEFAULT 0,
ADD COLUMN IF NOT EXISTS last_trip_date TEXT,
ADD COLUMN IF NOT EXISTS rating DECIMAL(3,2) DEFAULT 5.0;

-- Обновляем существующие записи, устанавливая значения по умолчанию
UPDATE profiles 
SET 
  today_earnings = COALESCE(today_earnings, 0),
  today_trips = COALESCE(today_trips, 0),
  total_earnings = COALESCE(total_earnings, 0),
  total_trips = COALESCE(total_trips, 0),
  rating = COALESCE(rating, 5.0)
WHERE 
  today_earnings IS NULL 
  OR today_trips IS NULL 
  OR total_earnings IS NULL 
  OR total_trips IS NULL 
  OR rating IS NULL;

-- Создаем индекс для быстрого поиска по дате последней поездки
CREATE INDEX IF NOT EXISTS idx_profiles_last_trip_date ON profiles(last_trip_date);

-- Комментарии к колонкам
COMMENT ON COLUMN profiles.today_earnings IS 'Заработок водителя за текущий день';
COMMENT ON COLUMN profiles.today_trips IS 'Количество поездок за текущий день';
COMMENT ON COLUMN profiles.total_earnings IS 'Общий заработок водителя';
COMMENT ON COLUMN profiles.total_trips IS 'Общее количество поездок';
COMMENT ON COLUMN profiles.last_trip_date IS 'Дата последней поездки (YYYY-MM-DD)';
COMMENT ON COLUMN profiles.rating IS 'Рейтинг водителя (от 1.0 до 5.0)';
