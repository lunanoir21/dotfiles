function venv_rm
    set -l venv_dir (status -c)
    if test -d "$venv_dir/venv"
        rm -rf "$venv_dir/venv"
        echo "venv removed from $venv_dir/venv"
    else
        echo "No venv directory found in $venv_dir"
    end
end