"""Console logging helpers shared by all v6 toolchain scripts."""


class TextColor:
	"""ANSI escape codes for colored terminal output."""
	BLACK = "\033[30m"
	RED = "\033[31m"
	GREEN = "\033[32m"
	YELLOW = "\033[33m"
	BLUE = "\033[34m"
	MAGENTA = "\033[35m"
	CYAN = "\033[36m"
	WHITE = "\033[37m"
	RESET = "\033[0m"
	GRAY = "\033[90m"
	GRAY_LIGHT = "\033[37m"


def printc(text, color=TextColor.WHITE):
	print(color + text + TextColor.RESET)


class ExportError(Exception):
	"""Raised when an export step fails. The CLI entry point converts it to a
	non-zero exit code so the outer toolchain can react."""

	def __init__(self, message, detail=""):
		super().__init__(message)
		self.detail = detail


def error(message, detail=""):
	"""Abort the current export with a descriptive error."""
	raise ExportError(message, detail)
