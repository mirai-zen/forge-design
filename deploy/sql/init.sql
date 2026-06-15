-- Forge Platform 初始化 SQL
-- 在你的 mysql 终端中执行：source /path/to/init.sql
-- 或者直接复制粘贴执行

CREATE DATABASE IF NOT EXISTS forge_platform
    CHARACTER SET utf8mb4
    COLLATE utf8mb4_unicode_ci;

USE forge_platform;

-- 1. 项目表（一个项目 = 一个 GitHub 仓库）
CREATE TABLE IF NOT EXISTS projects (
    id          BIGINT PRIMARY KEY AUTO_INCREMENT,
    name        VARCHAR(64)  NOT NULL UNIQUE COMMENT '项目名',
    git_org     VARCHAR(128) NOT NULL COMMENT 'GitHub Org',
    git_repo    VARCHAR(128) NOT NULL COMMENT '仓库名',
    template    VARCHAR(64)  NOT NULL COMMENT '项目模板名',
    created_at  DATETIME DEFAULT CURRENT_TIMESTAMP,
    updated_at  DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- 2. 服务表（一个项目下 N 个服务）
CREATE TABLE IF NOT EXISTS services (
    id          BIGINT PRIMARY KEY AUTO_INCREMENT,
    project_id  BIGINT       NOT NULL COMMENT '所属项目',
    name        VARCHAR(64)  NOT NULL COMMENT '服务名',
    template    VARCHAR(64)  NOT NULL COMMENT '模板名',
    params_json JSON         NOT NULL COMMENT '模板参数',
    created_at  DATETIME DEFAULT CURRENT_TIMESTAMP,
    updated_at  DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    UNIQUE KEY uk_project_service (project_id, name),
    FOREIGN KEY (project_id) REFERENCES projects(id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- 3. 环境表（每个服务创建时自动插入 3 条：dev / staging / prod）
CREATE TABLE IF NOT EXISTS service_envs (
    id          BIGINT PRIMARY KEY AUTO_INCREMENT,
    service_id  BIGINT       NOT NULL COMMENT '所属服务',
    env         VARCHAR(32)  NOT NULL COMMENT 'dev / staging / prod',
    namespace   VARCHAR(64)  NOT NULL COMMENT 'K8s namespace',
    created_at  DATETIME DEFAULT CURRENT_TIMESTAMP,
    UNIQUE KEY uk_service_env (service_id, env),
    FOREIGN KEY (service_id) REFERENCES services(id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- 验证
SHOW TABLES;
DESC projects;
DESC services;
DESC service_envs;
