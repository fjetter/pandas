from cython import Py_ssize_t

from cpython.dict cimport (
    PyDict_Contains,
    PyDict_GetItem,
    PyDict_SetItem,
)


cdef class CachedProperty:

    cdef readonly:
        object func, name, __doc__

    def __init__(self, func):
        self.func = func
        self.name = func.__name__
        self.__doc__ = getattr(func, '__doc__', None)

    def __get__(self, obj, typ):
        if obj is None:
            # accessed on the class, not the instance
            return self

        # Get the cache or set a default one if needed
        cache = instance_cache = getattr(obj, '_cache', None)

        if cache is None:
            try:
                cache = obj._cache = {}
            except (AttributeError):
                raise TypeError(
                    f"Cython extension type {type(obj)} must declare attribute "
                    "`_cache` to use @cache_readonly."
                )

        if instance_cache is not None:
            # When accessing cython extension types, the attribute is already
            # registered and known to the class, unlike for python object. To
            # ensure we're not accidentally using a global scope / class level
            # cache we'll need to check whether the instance and class
            # attribute is identical
            cache_class = getattr(typ, "_cache", None)
            if cache_class is not None and cache_class is instance_cache:
                raise TypeError(
                    f"Class {typ} defines a `_cache` attribute on class level "
                    "which is forbidden in combination with @cache_readonly."
                )

        if PyDict_Contains(cache, self.name):
            # not necessary to Py_INCREF
            val = <object>PyDict_GetItem(cache, self.name)
        else:
            val = self.func(obj)
            PyDict_SetItem(cache, self.name, val)
        return val

    def __set__(self, obj, value):
        raise AttributeError("Can't set attribute")


cache_readonly = CachedProperty


cdef class AxisProperty:

    cdef readonly:
        Py_ssize_t axis
        object __doc__

    def __init__(self, axis=0, doc=""):
        self.axis = axis
        self.__doc__ = doc

    def __get__(self, obj, type):
        cdef:
            list axes

        if obj is None:
            # Only instances have _mgr, not classes
            return self
        else:
            axes = obj._mgr.axes
        return axes[self.axis]

    def __set__(self, obj, value):
        obj._set_axis(self.axis, value)
