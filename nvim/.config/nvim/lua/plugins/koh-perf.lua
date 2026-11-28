-- 起動を軽くする設定。
-- Python などで書かれたプラグイン用の「プロバイダー」は使っていない (rplugin を持つプラグインが無い)。
-- 有効なままだと、Python のファイルを開くたびに Python 環境を探して約 0.18 秒止まる
-- (2026-11-28 に --startuptime で計測: provider/python3.vim 176ms / 起動全体 610ms)。
vim.g.loaded_python3_provider = 0
vim.g.loaded_ruby_provider = 0
vim.g.loaded_perl_provider = 0
vim.g.loaded_node_provider = 0

return {}
