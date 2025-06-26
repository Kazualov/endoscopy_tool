
import pytest
from videoQueries.voiceCommand import process_command

@pytest.mark.parametrize("input_text,expected", [
    ("старт", "start"),
    ("пожалуйста, старт", "start"),
    ("СТОП", "stop"),
    ("я хочу сохранить", "save"),
    ("Остановись", None),
    ("сделай скриншот", "screenshot"),
    ("ничего не делай", None),
])
def test_process_command(input_text, expected):
    result = process_command(input_text.lower())
    assert result == expected
