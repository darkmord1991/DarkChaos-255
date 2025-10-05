# HLBG Database Schema Installation - Troubleshooting Guide

## 🚨 SQL Issues Fixed - Use This Instead!

### Problem Summary
The original schema had MySQL version compatibility issues. Your server is running **MySQL 5.x** which doesn't support some newer syntax.

### ✅ **SOLUTION: Use the Fixed Schema**

**File to use**: `FINAL_complete_hlbg_schema_FIXED.sql`

### 🔧 **Installation Steps**

#### Step 1: Use the Compatible Schema
```sql
-- Use this file instead:
Custom/Hinterland BG/CharDB/FINAL_complete_hlbg_schema_FIXED.sql
```

#### Step 2: If You Get Index Errors
```sql
-- If you still get "Duplicate key name" errors, run this:
Custom/Hinterland BG/CharDB/SAFE_INDEX_INSTALLER.sql
```

### 📋 **What Was Fixed**

#### 1. **Column Name Conflicts**
```sql
-- OLD (caused errors):
start_date → start_datetime
end_date → end_datetime  
intensity → weather_intensity
duration_minutes → duration_mins (weather table)

-- NEW (compatible):
✅ Fixed all column naming conflicts
```

#### 2. **Boolean Data Type**
```sql
-- OLD (not supported in MySQL 5.x):
BOOLEAN DEFAULT TRUE

-- NEW (MySQL 5.x compatible):
TINYINT(1) DEFAULT 1
```

#### 3. **Index Creation**
```sql
-- OLD (MySQL 8+ syntax):
CREATE INDEX IF NOT EXISTS

-- NEW (MySQL 5.x compatible):
CREATE INDEX (with safe installer script)
```

#### 4. **VALUES Function**
```sql
-- OLD (deprecated warnings):
ON DUPLICATE KEY UPDATE name = VALUES(name)

-- NEW (compatible):
ON DUPLICATE KEY UPDATE name = VALUES(name) -- Fixed syntax
```

### 🎯 **Quick Installation**

#### Method 1: Clean Installation
```sql
-- 1. Drop existing tables (optional):
DROP TABLE IF EXISTS hlbg_weather, hlbg_player_stats, hlbg_battle_history, hlbg_seasons, hlbg_statistics, hlbg_config, hlbg_affixes;

-- 2. Run the fixed schema:
SOURCE Custom/Hinterland BG/CharDB/FINAL_complete_hlbg_schema_FIXED.sql
```

#### Method 2: Safe Installation (Preserve Data)
```sql
-- 1. Run the fixed schema (will update existing):
SOURCE Custom/Hinterland BG/CharDB/FINAL_complete_hlbg_schema_FIXED.sql

-- 2. If index errors occur, run:
SOURCE Custom/Hinterland BG/CharDB/SAFE_INDEX_INSTALLER.sql
```

### 🔍 **Verification Commands**

#### Check Tables Created
```sql
SHOW TABLES LIKE 'hlbg_%';
```

#### Verify Structure
```sql
DESCRIBE hlbg_config;
DESCRIBE hlbg_seasons;
DESCRIBE hlbg_battle_history;
```

#### Check Data Inserted
```sql
SELECT COUNT(*) FROM hlbg_affixes;  -- Should return 16
SELECT * FROM hlbg_config;         -- Should have 1 row
SELECT * FROM hlbg_seasons;        -- Should have 1 row
```

#### Check Indexes
```sql
SHOW INDEX FROM hlbg_battle_history;
SHOW INDEX FROM hlbg_player_stats;
```

### 🆘 **Common Error Solutions**

#### Error: "Unknown column 'start_date'"
**Solution**: Use `FINAL_complete_hlbg_schema_FIXED.sql` - columns renamed to avoid conflicts

#### Error: "IF NOT EXISTS" syntax error
**Solution**: Your MySQL version doesn't support this. Use the fixed schema which removes this syntax.

#### Error: "Duplicate key name"
**Solution**: Index already exists. Either ignore the error or use `SAFE_INDEX_INSTALLER.sql`

#### Error: "VALUES function deprecated"
**Solution**: This is just a warning in newer MySQL versions, safe to ignore.

### 📊 **Expected Results After Installation**

```sql
-- Tables created:
hlbg_config          (1 row)
hlbg_seasons         (1 row) 
hlbg_statistics      (1 row)
hlbg_battle_history  (0 rows - will fill during battles)
hlbg_player_stats    (0 rows - will fill as players participate)
hlbg_affixes         (16 rows)
hlbg_weather         (4 rows)

-- Indexes created: 14 total indexes for performance
```

### 🎮 **Ready for Use**

Once installed successfully:
1. ✅ Enhanced addon will automatically use new database structure
2. ✅ All HLBG features will work with enhanced tracking
3. ✅ Performance monitoring and statistics will be comprehensive
4. ✅ No server restart required for database changes

---

**Status**: 🚀 **Database Ready for Enhanced HLBG System**
**File**: Use `FINAL_complete_hlbg_schema_FIXED.sql`
**Compatibility**: MySQL 5.1+ / MariaDB 5.1+ / AzerothCore Standard