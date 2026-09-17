function venv_off
    if functions -q deactivate
        deactivate
        echo "venv deactivated"
    else
        echo "No active venv to deactivate"
    end
end