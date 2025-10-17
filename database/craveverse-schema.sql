-- CraveVerse Database Schema
-- Complete schema for the craving conquest platform

-- Enable necessary extensions
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- Create custom types
CREATE TYPE craving_type AS ENUM ('nofap', 'sugar', 'shopping', 'smoking_vaping', 'social_media');
CREATE TYPE subscription_tier AS ENUM ('free', 'plus', 'plus_trial', 'ultra');
CREATE TYPE battle_status AS ENUM ('waiting', 'active', 'completed', 'cancelled');
CREATE TYPE task_status AS ENUM ('pending', 'completed', 'skipped');
CREATE TYPE post_status AS ENUM ('active', 'hidden', 'deleted');
CREATE TYPE ai_model_type AS ENUM ('gpt-5-nano', 'gpt-5-mini');

-- Users table - Extended profile with craving data
CREATE TABLE users (
  id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
  clerk_user_id TEXT NOT NULL UNIQUE,
  email TEXT NOT NULL,
  name TEXT,
  avatar_url TEXT,
  primary_craving craving_type,
  current_level INTEGER DEFAULT 1,
  xp INTEGER DEFAULT 0,
  cravecoins INTEGER DEFAULT 0,
  streak_count INTEGER DEFAULT 0,
  subscription_tier subscription_tier DEFAULT 'free',
  trial_ends_at TIMESTAMP WITH TIME ZONE,
  ai_summary TEXT, -- Max 200 tokens for AI context
  preferences JSONB DEFAULT '{}',
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Cravings reference table
CREATE TABLE cravings (
  id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
  type craving_type NOT NULL UNIQUE,
  name TEXT NOT NULL,
  description TEXT NOT NULL,
  icon TEXT NOT NULL,
  color TEXT NOT NULL,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Levels table - 30 pre-authored templates per craving (150 total)
CREATE TABLE levels (
  id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
  craving_type craving_type NOT NULL,
  level_number INTEGER NOT NULL,
  title TEXT NOT NULL,
  description TEXT NOT NULL,
  challenge_text TEXT NOT NULL,
  success_criteria TEXT NOT NULL,
  xp_reward INTEGER NOT NULL,
  coin_reward INTEGER NOT NULL,
  estimated_duration_minutes INTEGER NOT NULL,
  difficulty TEXT NOT NULL CHECK (difficulty IN ('easy', 'medium', 'hard')),
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  UNIQUE(craving_type, level_number)
);

-- User progress tracking
CREATE TABLE user_progress (
  id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
  user_id UUID REFERENCES users(id) ON DELETE CASCADE,
  level_id UUID REFERENCES levels(id) ON DELETE CASCADE,
  completed_at TIMESTAMP WITH TIME ZONE,
  ai_feedback TEXT,
  user_response TEXT,
  relapse_count INTEGER DEFAULT 0,
  metadata JSONB DEFAULT '{}',
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  UNIQUE(user_id, level_id)
);

-- Battles table - 1v1 matchmaking
CREATE TABLE battles (
  id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
  user1_id UUID REFERENCES users(id) ON DELETE CASCADE,
  user2_id UUID REFERENCES users(id) ON DELETE CASCADE,
  craving_type craving_type NOT NULL,
  status battle_status DEFAULT 'waiting',
  tasks JSONB, -- Array of 3 task objects
  start_time TIMESTAMP WITH TIME ZONE,
  end_time TIMESTAMP WITH TIME ZONE,
  winner_id UUID REFERENCES users(id),
  user1_tasks_completed INTEGER DEFAULT 0,
  user2_tasks_completed INTEGER DEFAULT 0,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Battle tasks - AI-generated extra challenges, cached for reuse
CREATE TABLE battle_tasks (
  id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
  craving_type craving_type NOT NULL,
  task_text TEXT NOT NULL,
  reuse_count INTEGER DEFAULT 0,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Forum posts
CREATE TABLE forum_posts (
  id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
  user_id UUID REFERENCES users(id) ON DELETE CASCADE,
  craving_type craving_type NOT NULL,
  title TEXT NOT NULL,
  content TEXT NOT NULL,
  ai_reply_suggested TEXT,
  upvotes INTEGER DEFAULT 0,
  status post_status DEFAULT 'active',
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Forum replies
CREATE TABLE forum_replies (
  id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
  post_id UUID REFERENCES forum_posts(id) ON DELETE CASCADE,
  user_id UUID REFERENCES users(id) ON DELETE CASCADE,
  parent_reply_id UUID REFERENCES forum_replies(id),
  content TEXT NOT NULL,
  ai_generated BOOLEAN DEFAULT FALSE,
  upvotes INTEGER DEFAULT 0,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Pause tokens - User inventory and usage log
CREATE TABLE pause_tokens (
  id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
  user_id UUID REFERENCES users(id) ON DELETE CASCADE,
  tokens_available INTEGER DEFAULT 0,
  tokens_used INTEGER DEFAULT 0,
  last_reset_date DATE DEFAULT CURRENT_DATE,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- AI usage metrics - Per-user monthly token tracking
CREATE TABLE ai_usage_metrics (
  id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
  user_id UUID REFERENCES users(id) ON DELETE CASCADE,
  model_type ai_model_type NOT NULL,
  tokens_used INTEGER NOT NULL,
  cost_usd DECIMAL(10, 6) NOT NULL,
  prompt_hash TEXT NOT NULL,
  cached_response BOOLEAN DEFAULT FALSE,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Shareable progress - Public token-based progress snapshots
CREATE TABLE shareable_progress (
  id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
  user_id UUID REFERENCES users(id) ON DELETE CASCADE,
  public_token TEXT NOT NULL UNIQUE,
  progress_data JSONB NOT NULL,
  expires_at TIMESTAMP WITH TIME ZONE,
  view_count INTEGER DEFAULT 0,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Payment transactions - Stripe integration logs
CREATE TABLE payment_transactions (
  id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
  user_id UUID REFERENCES users(id) ON DELETE CASCADE,
  stripe_payment_intent_id TEXT NOT NULL,
  amount_cents INTEGER NOT NULL,
  currency TEXT NOT NULL DEFAULT 'usd',
  product_type TEXT NOT NULL, -- 'subscription', 'coins', 'pause_tokens'
  product_id TEXT NOT NULL,
  status TEXT NOT NULL,
  metadata JSONB DEFAULT '{}',
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Queue jobs for batched AI processing
CREATE TABLE queue_jobs (
  id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
  job_type TEXT NOT NULL,
  payload JSONB NOT NULL,
  status TEXT DEFAULT 'pending' CHECK (status IN ('pending', 'processing', 'completed', 'failed')),
  scheduled_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  processed_at TIMESTAMP WITH TIME ZONE,
  error_message TEXT,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Admin users for moderation
CREATE TABLE admin_users (
  id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
  clerk_user_id TEXT NOT NULL UNIQUE,
  role TEXT NOT NULL DEFAULT 'moderator' CHECK (role IN ('moderator', 'admin', 'super_admin')),
  permissions JSONB DEFAULT '{}',
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Create indexes for better performance
CREATE INDEX idx_users_clerk_user_id ON users(clerk_user_id);
CREATE INDEX idx_users_subscription_tier ON users(subscription_tier);
CREATE INDEX idx_users_primary_craving ON users(primary_craving);
CREATE INDEX idx_users_streak_count ON users(streak_count);

CREATE INDEX idx_levels_craving_type ON levels(craving_type);
CREATE INDEX idx_levels_level_number ON levels(level_number);

CREATE INDEX idx_user_progress_user_id ON user_progress(user_id);
CREATE INDEX idx_user_progress_level_id ON user_progress(level_id);
CREATE INDEX idx_user_progress_completed_at ON user_progress(completed_at);

CREATE INDEX idx_battles_user1_id ON battles(user1_id);
CREATE INDEX idx_battles_user2_id ON battles(user2_id);
CREATE INDEX idx_battles_status ON battles(status);
CREATE INDEX idx_battles_craving_type ON battles(craving_type);

CREATE INDEX idx_battle_tasks_craving_type ON battle_tasks(craving_type);

CREATE INDEX idx_forum_posts_craving_type ON forum_posts(craving_type);
CREATE INDEX idx_forum_posts_user_id ON forum_posts(user_id);
CREATE INDEX idx_forum_posts_created_at ON forum_posts(created_at);

CREATE INDEX idx_forum_replies_post_id ON forum_replies(post_id);
CREATE INDEX idx_forum_replies_user_id ON forum_replies(user_id);

CREATE INDEX idx_ai_usage_metrics_user_id ON ai_usage_metrics(user_id);
CREATE INDEX idx_ai_usage_metrics_created_at ON ai_usage_metrics(created_at);

CREATE INDEX idx_queue_jobs_status ON queue_jobs(status);
CREATE INDEX idx_queue_jobs_scheduled_at ON queue_jobs(scheduled_at);

-- Create updated_at trigger function
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ language 'plpgsql';

-- Add updated_at triggers
CREATE TRIGGER update_users_updated_at BEFORE UPDATE ON users
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_forum_posts_updated_at BEFORE UPDATE ON forum_posts
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_pause_tokens_updated_at BEFORE UPDATE ON pause_tokens
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- Enable Row Level Security (RLS)
ALTER TABLE users ENABLE ROW LEVEL SECURITY;
ALTER TABLE user_progress ENABLE ROW LEVEL SECURITY;
ALTER TABLE battles ENABLE ROW LEVEL SECURITY;
ALTER TABLE forum_posts ENABLE ROW LEVEL SECURITY;
ALTER TABLE forum_replies ENABLE ROW LEVEL SECURITY;
ALTER TABLE pause_tokens ENABLE ROW LEVEL SECURITY;
ALTER TABLE ai_usage_metrics ENABLE ROW LEVEL SECURITY;
ALTER TABLE shareable_progress ENABLE ROW LEVEL SECURITY;
ALTER TABLE payment_transactions ENABLE ROW LEVEL SECURITY;

-- Create RLS policies for users
CREATE POLICY "Users can view their own profile" ON users
    FOR SELECT USING (auth.uid()::text = clerk_user_id);

CREATE POLICY "Users can update their own profile" ON users
    FOR UPDATE USING (auth.uid()::text = clerk_user_id);

-- Create RLS policies for user_progress
CREATE POLICY "Users can view their own progress" ON user_progress
    FOR SELECT USING (user_id IN (SELECT id FROM users WHERE clerk_user_id = auth.uid()::text));

CREATE POLICY "Users can insert their own progress" ON user_progress
    FOR INSERT WITH CHECK (user_id IN (SELECT id FROM users WHERE clerk_user_id = auth.uid()::text));

CREATE POLICY "Users can update their own progress" ON user_progress
    FOR UPDATE USING (user_id IN (SELECT id FROM users WHERE clerk_user_id = auth.uid()::text));

-- Create RLS policies for battles
CREATE POLICY "Users can view their own battles" ON battles
    FOR SELECT USING (user1_id IN (SELECT id FROM users WHERE clerk_user_id = auth.uid()::text) 
                      OR user2_id IN (SELECT id FROM users WHERE clerk_user_id = auth.uid()::text));

CREATE POLICY "Users can insert their own battles" ON battles
    FOR INSERT WITH CHECK (user1_id IN (SELECT id FROM users WHERE clerk_user_id = auth.uid()::text));

CREATE POLICY "Users can update their own battles" ON battles
    FOR UPDATE USING (user1_id IN (SELECT id FROM users WHERE clerk_user_id = auth.uid()::text) 
                      OR user2_id IN (SELECT id FROM users WHERE clerk_user_id = auth.uid()::text));

-- Create RLS policies for forum_posts
CREATE POLICY "Users can view all forum posts" ON forum_posts
    FOR SELECT USING (true);

CREATE POLICY "Users can insert their own forum posts" ON forum_posts
    FOR INSERT WITH CHECK (user_id IN (SELECT id FROM users WHERE clerk_user_id = auth.uid()::text));

CREATE POLICY "Users can update their own forum posts" ON forum_posts
    FOR UPDATE USING (user_id IN (SELECT id FROM users WHERE clerk_user_id = auth.uid()::text));

-- Create RLS policies for forum_replies
CREATE POLICY "Users can view all forum replies" ON forum_replies
    FOR SELECT USING (true);

CREATE POLICY "Users can insert their own forum replies" ON forum_replies
    FOR INSERT WITH CHECK (user_id IN (SELECT id FROM users WHERE clerk_user_id = auth.uid()::text));

CREATE POLICY "Users can update their own forum replies" ON forum_replies
    FOR UPDATE USING (user_id IN (SELECT id FROM users WHERE clerk_user_id = auth.uid()::text));

-- Create RLS policies for pause_tokens
CREATE POLICY "Users can view their own pause tokens" ON pause_tokens
    FOR SELECT USING (user_id IN (SELECT id FROM users WHERE clerk_user_id = auth.uid()::text));

CREATE POLICY "Users can update their own pause tokens" ON pause_tokens
    FOR UPDATE USING (user_id IN (SELECT id FROM users WHERE clerk_user_id = auth.uid()::text));

-- Create RLS policies for ai_usage_metrics
CREATE POLICY "Users can view their own AI usage" ON ai_usage_metrics
    FOR SELECT USING (user_id IN (SELECT id FROM users WHERE clerk_user_id = auth.uid()::text));

-- Create RLS policies for shareable_progress
CREATE POLICY "Users can view their own shareable progress" ON shareable_progress
    FOR SELECT USING (user_id IN (SELECT id FROM users WHERE clerk_user_id = auth.uid()::text));

CREATE POLICY "Users can insert their own shareable progress" ON shareable_progress
    FOR INSERT WITH CHECK (user_id IN (SELECT id FROM users WHERE clerk_user_id = auth.uid()::text));

-- Create RLS policies for payment_transactions
CREATE POLICY "Users can view their own payment transactions" ON payment_transactions
    FOR SELECT USING (user_id IN (SELECT id FROM users WHERE clerk_user_id = auth.uid()::text));

-- Insert craving types
INSERT INTO cravings (type, name, description, icon, color) VALUES
('nofap', 'NoFap', 'Overcome pornography addiction and build self-control', '🚫', '#FF6B6B'),
('sugar', 'Sugar Free', 'Break free from sugar addiction and improve health', '🍭', '#FFD93D'),
('shopping', 'Shopping Control', 'Stop impulse buying and save money', '🛍️', '#6BCF7F'),
('smoking_vaping', 'Smoke Free', 'Quit smoking and vaping for better health', '🚭', '#4ECDC4'),
('social_media', 'Social Media Detox', 'Reduce social media usage and reclaim time', '📱', '#A8E6CF')
ON CONFLICT (type) DO NOTHING;

-- Create functions for common operations

-- Function to get user's progress statistics
CREATE OR REPLACE FUNCTION get_user_progress_stats(user_id_param UUID)
RETURNS TABLE (
    total_levels_completed BIGINT,
    current_streak BIGINT,
    total_xp BIGINT,
    total_coins BIGINT,
    current_level_number BIGINT
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        COUNT(up.id) as total_levels_completed,
        u.streak_count as current_streak,
        u.xp as total_xp,
        u.cravecoins as total_coins,
        u.current_level as current_level_number
    FROM users u
    LEFT JOIN user_progress up ON u.id = up.user_id AND up.completed_at IS NOT NULL
    WHERE u.id = user_id_param
    GROUP BY u.id, u.streak_count, u.xp, u.cravecoins, u.current_level;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to check if user can access level
CREATE OR REPLACE FUNCTION can_access_level(user_id_param UUID, level_number_param INTEGER)
RETURNS BOOLEAN AS $$
DECLARE
    user_tier subscription_tier;
    max_levels INTEGER;
BEGIN
    SELECT subscription_tier INTO user_tier FROM users WHERE id = user_id_param;
    
    CASE user_tier
        WHEN 'free' THEN max_levels := 10;
        WHEN 'plus', 'plus_trial', 'ultra' THEN max_levels := 30;
        ELSE max_levels := 0;
    END CASE;
    
    RETURN level_number_param <= max_levels;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to award XP and coins
CREATE OR REPLACE FUNCTION award_xp_and_coins(
    user_id_param UUID,
    xp_amount INTEGER,
    coin_amount INTEGER
)
RETURNS VOID AS $$
BEGIN
    UPDATE users 
    SET xp = xp + xp_amount,
        cravecoins = cravecoins + coin_amount,
        updated_at = NOW()
    WHERE id = user_id_param;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to update streak
CREATE OR REPLACE FUNCTION update_streak(user_id_param UUID, increment BOOLEAN DEFAULT TRUE)
RETURNS VOID AS $$
BEGIN
    IF increment THEN
        UPDATE users 
        SET streak_count = streak_count + 1,
            updated_at = NOW()
        WHERE id = user_id_param;
    ELSE
        UPDATE users 
        SET streak_count = 0,
            updated_at = NOW()
        WHERE id = user_id_param;
    END IF;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to log AI usage
CREATE OR REPLACE FUNCTION log_ai_usage(
    user_id_param UUID,
    model_type_param ai_model_type,
    tokens_used_param INTEGER,
    cost_usd_param DECIMAL(10, 6),
    prompt_hash_param TEXT,
    cached_response_param BOOLEAN DEFAULT FALSE
)
RETURNS UUID AS $$
DECLARE
    usage_id UUID;
BEGIN
    INSERT INTO ai_usage_metrics (user_id, model_type, tokens_used, cost_usd, prompt_hash, cached_response)
    VALUES (user_id_param, model_type_param, tokens_used_param, cost_usd_param, prompt_hash_param, cached_response_param)
    RETURNING id INTO usage_id;
    
    RETURN usage_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Create views for common queries

-- View for user dashboard data
CREATE VIEW user_dashboard AS
SELECT 
    u.id,
    u.clerk_user_id,
    u.name,
    u.email,
    u.primary_craving,
    u.current_level,
    u.xp,
    u.cravecoins,
    u.streak_count,
    u.subscription_tier,
    c.name as craving_name,
    c.icon as craving_icon,
    c.color as craving_color
FROM users u
LEFT JOIN cravings c ON u.primary_craving = c.type;

-- View for level details with user progress
CREATE VIEW level_details AS
SELECT 
    l.*,
    up.completed_at,
    up.ai_feedback,
    up.user_response,
    up.relapse_count
FROM levels l
LEFT JOIN user_progress up ON l.id = up.level_id;

-- View for battle details
CREATE VIEW battle_details AS
SELECT 
    b.*,
    u1.name as user1_name,
    u2.name as user2_name,
    c.name as craving_name
FROM battles b
LEFT JOIN users u1 ON b.user1_id = u1.id
LEFT JOIN users u2 ON b.user2_id = u2.id
LEFT JOIN cravings c ON b.craving_type = c.type;

-- View for forum post details
CREATE VIEW forum_post_details AS
SELECT 
    fp.*,
    u.name as author_name,
    u.avatar_url as author_avatar,
    u.subscription_tier as author_tier,
    COUNT(fr.id) as reply_count
FROM forum_posts fp
LEFT JOIN users u ON fp.user_id = u.id
LEFT JOIN forum_replies fr ON fp.id = fr.post_id
GROUP BY fp.id, u.name, u.avatar_url, u.subscription_tier;
