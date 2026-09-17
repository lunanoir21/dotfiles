function venv_crate
    set -l venv_dir $PWD
    if not test -d "$venv_dir/venv"
        python -m venv "$venv_dir/venv"
        echo "venv created at $venv_dir/venv"
    else
        echo "venv already exists at $venv_dir/venv"
    end
end