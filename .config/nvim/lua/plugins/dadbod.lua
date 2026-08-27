local sql_ft = { "sql", "mysql", "plsql" }

return {
  {
    "tpope/vim-dadbod",
    cmd = "DB",
    lazy = true,
  },
  {
    "kristijanhusak/vim-dadbod-completion",
    ft = sql_ft,
    lazy = true,
  },
  {
    "kristijanhusak/vim-dadbod-ui",
    dependencies = {
      { "tpope/vim-dadbod", lazy = true },
      { "kristijanhusak/vim-dadbod-completion", ft = sql_ft, lazy = true },
    },
    cmd = {
      "DBUI",
      "DBUIToggle",
      "DBUIAddConnection",
      "DBUIFindBuffer",
      "DBUILastQueryInfo",
    },
    keys = {
      { "<leader>D", "<cmd>DBUIToggle<cr>", desc = "Toggle DBUI Drawer" },
      { "<leader>df", "<cmd>DBUIFindBuffer<cr>", desc = "Find DBUI Buffer" },
      { "<leader>dr", "<cmd>DBUILastQueryInfo<cr>", desc = "Last Query Info" },
    },
    init = function()
      local data_path = vim.fn.stdpath("data")

      vim.g.db_ui_use_nerd_fonts = 1
      vim.g.db_ui_show_database_icon = 1
      vim.g.db_ui_win_position = "left"
      vim.g.db_ui_winwidth = 38
      vim.g.db_ui_auto_execute_table_helpers = 1
      vim.g.db_ui_use_postgres_views = 1
      vim.g.db_ui_execute_on_save = 0
      vim.g.db_ui_hide_schemas = { "pg_toast", "pg_temp.*", "information_schema" }

      vim.g.db_ui_save_location = data_path .. "/dadbod_ui"
      vim.g.db_ui_tmp_query_location = data_path .. "/dadbod_ui/tmp"

      -- Safe default query (avoids missing 'id' column crash on M2M relation tables)
      vim.g.db_ui_default_query = 'SELECT * FROM {optional_schema}"{table}" LIMIT 50;'

      -- Preconfigured Odoo Database Connections (matches docker-compose.yml / odoo.conf)
      local db_user = vim.env.ODOO_DB_USER or "odoo"
      local db_pass = vim.env.ODOO_DB_PASSWORD or "odoo"
      local db_host = vim.env.ODOO_DB_HOST or "127.0.0.1"
      local db_port = vim.env.ODOO_DB_PORT or "5432"
      vim.g.dbs = {
        odoo_postgres = string.format("postgresql://%s:%s@%s:%s/postgres", db_user, db_pass, db_host, db_port),
        odoo_test_db = string.format("postgresql://%s:%s@%s:%s/test_db", db_user, db_pass, db_host, db_port),
      }

      -- Custom Odoo PostgreSQL Table Helpers (Press H on table in DBUI)
      vim.g.db_ui_table_helpers = {
        postgresql = {
          -- Default list override (replaces deprecated g:db_ui_default_query)
          ["List"] = 'SELECT * FROM {optional_schema}"{table}" LIMIT 50;',

          ["Count Records (Exact)"] = 'SELECT count(*) AS exact_count FROM {optional_schema}"{table}";',

          ["Estimated Count & Stats (Fast)"] = [[
            SELECT
              GREATEST(0, c.reltuples::bigint) AS estimated_count,
              s.n_live_tup AS live_tuples,
              s.n_dead_tup AS dead_tuples,
              s.last_vacuum,
              s.last_autovacuum,
              s.last_analyze,
              s.last_autoanalyze
            FROM pg_class c
            JOIN pg_namespace n ON n.oid = c.relnamespace
            LEFT JOIN pg_stat_user_tables s ON s.relid = c.oid
            WHERE c.relname = '{table}'
              AND n.nspname = COALESCE(NULLIF('{schema}', ''), 'public');
          ]],

          ["Latest 50 (by ID)"] = 'SELECT * FROM {optional_schema}"{table}" ORDER BY id DESC LIMIT 50;',

          ["Latest Modified (by write_date)"] = [[
            SELECT * FROM {optional_schema}"{table}"
            ORDER BY write_date DESC NULLS LAST
            LIMIT 50;
          ]],

          ["Describe Table Schema"] = [[
            SELECT
              a.attname AS column_name,
              format_type(a.atttypid, a.atttypmod) AS data_type,
              NOT a.attnotnull AS is_nullable,
              pg_get_expr(d.adbin, d.adrelid) AS column_default,
              col_description(a.attrelid, a.attnum) AS description
            FROM pg_attribute a
            JOIN pg_class c ON c.oid = a.attrelid
            JOIN pg_namespace n ON n.oid = c.relnamespace
            LEFT JOIN pg_attrdef d ON d.adrelid = a.attrelid AND d.adnum = a.attnum
            WHERE c.relname = '{table}'
              AND n.nspname = COALESCE(NULLIF('{schema}', ''), 'public')
              AND a.attnum > 0
              AND NOT a.attisdropped
            ORDER BY a.attnum;
          ]],

          ["Table & Index Size"] = [[
            SELECT
              pg_size_pretty(pg_total_relation_size('{optional_schema}"{table}"')) AS total_size,
              pg_size_pretty(pg_relation_size('{optional_schema}"{table}"')) AS data_size,
              pg_size_pretty(pg_indexes_size('{optional_schema}"{table}"')) AS index_size,
              pg_size_pretty(pg_total_relation_size('{optional_schema}"{table}"') - pg_relation_size('{optional_schema}"{table}"') - pg_indexes_size('{optional_schema}"{table}"')) AS toast_size;
          ]],

          ["Odoo XML IDs (ir_model_data)"] = [[
            SELECT
              module,
              name AS xml_id,
              module || '.' || name AS complete_xml_id,
              res_id,
              noupdate
            FROM ir_model_data
            WHERE model IN (
              SELECT model FROM ir_model WHERE replace(model, '.', '_') = '{table}' OR model = '{table}'
            ) OR model = replace('{table}', '_', '.') OR model = '{table}'
            ORDER BY id DESC
            LIMIT 100;
          ]],

          ["Odoo Field Definitions"] = [[
            SELECT
              f.name,
              COALESCE(f.field_description->>'en_US', (SELECT value FROM jsonb_each_text(to_jsonb(f.field_description)) LIMIT 1), f.field_description::text) AS label,
              f.ttype AS type,
              f.relation AS comodel,
              f.relation_field AS inverse_field,
              f.on_delete,
              f.store,
              f.required,
              f.readonly,
              f.index,
              f.compute,
              f.related
            FROM ir_model_fields f
            JOIN ir_model m ON f.model_id = m.id
            WHERE replace(m.model, '.', '_') = '{table}' OR m.model = '{table}'
            ORDER BY f.name;
          ]],

          ["Odoo Views (ir_ui_view)"] = [[
            SELECT
              v.id,
              v.name,
              v.type,
              v.priority,
              v.mode,
              v.active,
              v.inherit_id,
              COALESCE(p.name, '') AS inherit_parent_name,
              (SELECT d.module || '.' || d.name FROM ir_model_data d WHERE d.model = 'ir.ui.view' AND d.res_id = v.id ORDER BY d.id LIMIT 1) AS xml_id
            FROM ir_ui_view v
            LEFT JOIN ir_ui_view p ON p.id = v.inherit_id
            WHERE v.model IN (
              SELECT model FROM ir_model WHERE replace(model, '.', '_') = '{table}' OR model = '{table}'
            ) OR v.model = replace('{table}', '_', '.') OR v.model = '{table}'
            ORDER BY v.type, v.priority, v.name;
          ]],

          ["Odoo Security Rules (ir_rule)"] = [[
            SELECT
              r.name,
              r.active,
              COALESCE(string_agg(COALESCE(g.name->>'en_US', (SELECT value FROM jsonb_each_text(to_jsonb(g.name)) LIMIT 1), g.name::text), ', '), '[GLOBAL - All Users]') AS applied_groups,
              r.perm_read AS read,
              r.perm_write AS write,
              r.perm_create AS create,
              r.perm_unlink AS unlink,
              r.domain_force,
              (SELECT d.module || '.' || d.name FROM ir_model_data d WHERE d.model = 'ir.rule' AND d.res_id = r.id ORDER BY d.id LIMIT 1) AS xml_id
            FROM ir_rule r
            JOIN ir_model m ON r.model_id = m.id
            LEFT JOIN rule_group_rel rg ON r.id = rg.rule_group_id
            LEFT JOIN res_groups g ON rg.group_id = g.id
            WHERE replace(m.model, '.', '_') = '{table}' OR m.model = '{table}'
            GROUP BY r.id, r.name, r.active, r.perm_read, r.perm_write, r.perm_create, r.perm_unlink, r.domain_force
            ORDER BY r.name;
          ]],

          ["Odoo Access Rights (ir_model_access)"] = [[
            SELECT
              a.name,
              a.active,
              COALESCE(g.name->>'en_US', (SELECT value FROM jsonb_each_text(to_jsonb(g.name)) LIMIT 1), g.name::text, '[GLOBAL - All Users]') AS group_name,
              a.perm_read AS read,
              a.perm_write AS write,
              a.perm_create AS create,
              a.perm_unlink AS unlink,
              (SELECT d.module || '.' || d.name FROM ir_model_data d WHERE d.model = 'ir.model.access' AND d.res_id = a.id ORDER BY d.id LIMIT 1) AS xml_id
            FROM ir_model_access a
            JOIN ir_model m ON a.model_id = m.id
            LEFT JOIN res_groups g ON a.group_id = g.id
            WHERE replace(m.model, '.', '_') = '{table}' OR m.model = '{table}'
            ORDER BY a.name;
          ]],

          ["Odoo Model SQL Constraints (ir_model_constraint)"] = [[
            SELECT
              c.name AS constraint_name,
              c.type,
              c.definition,
              COALESCE(m.name, '') AS module_name,
              c.write_date
            FROM ir_model_constraint c
            JOIN ir_model md ON c.model = md.id
            LEFT JOIN ir_module_module m ON c.module = m.id
            WHERE replace(md.model, '.', '_') = '{table}' OR md.model = '{table}'
            ORDER BY c.name;
          ]],

          ["Outgoing FKs (with ondelete)"] = [[
            SELECT
              con.conname AS constraint_name,
              att2.attname AS local_column,
              cl.relname AS foreign_table,
              att.attname AS foreign_column,
              CASE con.confdeltype
                WHEN 'a' THEN 'NO ACTION'
                WHEN 'r' THEN 'RESTRICT'
                WHEN 'c' THEN 'CASCADE'
                WHEN 'n' THEN 'SET NULL'
                WHEN 'd' THEN 'SET DEFAULT'
              END AS on_delete
            FROM pg_constraint con
            JOIN pg_class c ON c.oid = con.conrelid
            JOIN pg_namespace n ON n.oid = c.relnamespace
            JOIN pg_class cl ON cl.oid = con.confrelid
            JOIN LATERAL unnest(con.conkey, con.confkey) WITH ORDINALITY AS cols(conkey_num, confkey_num, ord) ON true
            JOIN pg_attribute att2 ON att2.attrelid = con.conrelid AND att2.attnum = cols.conkey_num
            JOIN pg_attribute att ON att.attrelid = con.confrelid AND att.attnum = cols.confkey_num
            WHERE con.contype = 'f'
              AND c.relname = '{table}'
              AND n.nspname = COALESCE(NULLIF('{schema}', ''), 'public')
            ORDER BY local_column;
          ]],

          ["Incoming FKs (References to this Table)"] = [[
            SELECT
              con.conname AS constraint_name,
              cl.relname AS referring_table,
              att.attname AS referring_column,
              att2.attname AS referenced_column,
              CASE con.confdeltype
                WHEN 'a' THEN 'NO ACTION'
                WHEN 'r' THEN 'RESTRICT'
                WHEN 'c' THEN 'CASCADE'
                WHEN 'n' THEN 'SET NULL'
                WHEN 'd' THEN 'SET DEFAULT'
              END AS on_delete
            FROM pg_constraint con
            JOIN pg_class c ON c.oid = con.confrelid
            JOIN pg_namespace n ON n.oid = c.relnamespace
            JOIN pg_class cl ON cl.oid = con.conrelid
            JOIN LATERAL unnest(con.conkey, con.confkey) WITH ORDINALITY AS cols(conkey_num, confkey_num, ord) ON true
            JOIN pg_attribute att ON att.attrelid = con.conrelid AND att.attnum = cols.conkey_num
            JOIN pg_attribute att2 ON att2.attrelid = con.confrelid AND att2.attnum = cols.confkey_num
            WHERE con.contype = 'f'
              AND c.relname = '{table}'
              AND n.nspname = COALESCE(NULLIF('{schema}', ''), 'public')
            ORDER BY referring_table, referring_column;
          ]],

          ["Unindexed FKs (Performance Check)"] = [[
            SELECT
              c.conname AS fk_constraint,
              att.attname AS fk_column,
              cf.relname AS foreign_table
            FROM pg_constraint c
            JOIN pg_class cl ON cl.oid = c.conrelid
            JOIN pg_namespace n ON n.oid = cl.relnamespace
            JOIN pg_class cf ON cf.oid = c.confrelid
            JOIN pg_attribute att ON att.attrelid = c.conrelid AND att.attnum = c.conkey[1]
            WHERE c.contype = 'f'
              AND cl.relname = '{table}'
              AND n.nspname = COALESCE(NULLIF('{schema}', ''), 'public')
              AND NOT EXISTS (
                SELECT 1 FROM pg_index i
                WHERE i.indrelid = c.conrelid
                  AND i.indkey[0] = c.conkey[1]
              )
            ORDER BY fk_column;
          ]],

          ["Table Bloat & Activity Stats"] = [[
            SELECT
              seq_scan,
              seq_tup_read,
              idx_scan,
              idx_tup_fetch,
              n_tup_ins AS inserts,
              n_tup_upd AS updates,
              n_tup_del AS deletes,
              n_live_tup AS live_tuples,
              n_dead_tup AS dead_tuples,
              round(n_dead_tup * 100.0 / NULLIF(n_live_tup + n_dead_tup, 0), 2) AS dead_tuple_pct,
              last_vacuum,
              last_autovacuum,
              last_analyze,
              last_autoanalyze
            FROM pg_stat_user_tables
            WHERE relname = '{table}'
              AND schemaname = COALESCE(NULLIF('{schema}', ''), 'public');
          ]],
        },
      }
    end,
  },
  {
    "saghen/blink.cmp",
    optional = true,
    opts = {
      sources = {
        per_filetype = {
          sql = { "dadbod", "snippets", "buffer" },
          mysql = { "dadbod", "snippets", "buffer" },
          plsql = { "dadbod", "snippets", "buffer" },
        },
        providers = {
          dadbod = {
            name = "Dadbod",
            module = "vim_dadbod_completion.blink",
            score_offset = 100,
          },
        },
      },
    },
  },
}
