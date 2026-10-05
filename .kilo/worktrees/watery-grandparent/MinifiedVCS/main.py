import hashlib
from abc import ABC, abstractmethod

class MinifiedVCS(ABC):
    def __init__(self, content):
        