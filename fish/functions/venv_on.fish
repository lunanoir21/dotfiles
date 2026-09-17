function venv_on
    set -l venv_dir (status -c)
    if test -d "$venv_dir/venv"
        source "$venv_dir/venv/bin/activate"
        echo "venv activated from $venv_dir/venv"
    else
        echo "No venv found in $venv_dir"
        echo "Usage: cd /path/to/project && venv_on"
    end
end