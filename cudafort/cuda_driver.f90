! ==========================================================================
!  cuda_driver.f90 -- Fortran 2008 iso_c_binding interface to the CUDA Driver API
!
!  GENERATED FILE -- do not edit by hand.
!  Regenerate with:  python3 generate_cuda_fortran.py
!  Generated from CUDA 12.9 headers at:
!      /apps/cuda/12.9.0/include
!
!  Standard Fortran 2008 only -- no compiler extensions. Builds with
!  gfortran, ifx, flang and nvfortran, and is independent of cudafor.
!
!  Conventions
!  -----------
!  * Every entry point returns its C status code as an INTEGER(c_int)
!    function result (cudaError_t / CUresult).
!  * Opaque handles (streams, events, graphs, arrays, ...) are pointers
!    in C and map to TYPE(c_ptr): by VALUE when passed in, INTENT(OUT)
!    when returned (C  T*  where T is itself a pointer typedef).
!  * Device and host buffers (void*, T*) are TYPE(c_ptr), VALUE. Pass a
!    device address, or C_LOC(host_array) for host data.
!  * Enumerators are PUBLIC INTEGER(c_int) PARAMETERs with their C names.
!  * Structs are BIND(C) derived types whose layout has been verified
!    against sizeof/offsetof from a compiled C probe. C unions have no
!    Fortran equivalent and appear as INTEGER(c_int8_t) byte arrays of
!    the correct size.
!  * Fortran is case-insensitive; the C names are preserved verbatim and
!    checked for case-insensitive collisions at generation time.
! ==========================================================================
module cuda_driver
    use, intrinsic :: iso_c_binding
    implicit none
    public

    ! ======================================================================
    !  Enumerations
    ! ======================================================================
    ! ---- CUipcMem_flags
    integer(c_int), parameter :: CU_IPC_MEM_LAZY_ENABLE_PEER_ACCESS = 1

    ! ---- CUmemAttach_flags
    integer(c_int), parameter :: CU_MEM_ATTACH_GLOBAL = 1
    integer(c_int), parameter :: CU_MEM_ATTACH_HOST = 2
    integer(c_int), parameter :: CU_MEM_ATTACH_SINGLE = 4

    ! ---- CUctx_flags
    integer(c_int), parameter :: CU_CTX_SCHED_AUTO = 0
    integer(c_int), parameter :: CU_CTX_SCHED_SPIN = 1
    integer(c_int), parameter :: CU_CTX_SCHED_YIELD = 2
    integer(c_int), parameter :: CU_CTX_SCHED_BLOCKING_SYNC = 4
    integer(c_int), parameter :: CU_CTX_BLOCKING_SYNC = 4
    integer(c_int), parameter :: CU_CTX_SCHED_MASK = 7
    integer(c_int), parameter :: CU_CTX_MAP_HOST = 8
    integer(c_int), parameter :: CU_CTX_LMEM_RESIZE_TO_MAX = 16
    integer(c_int), parameter :: CU_CTX_COREDUMP_ENABLE = 32
    integer(c_int), parameter :: CU_CTX_USER_COREDUMP_ENABLE = 64
    integer(c_int), parameter :: CU_CTX_SYNC_MEMOPS = 128
    integer(c_int), parameter :: CU_CTX_FLAGS_MASK = 255

    ! ---- CUevent_sched_flags
    integer(c_int), parameter :: CU_EVENT_SCHED_AUTO = 0
    integer(c_int), parameter :: CU_EVENT_SCHED_SPIN = 1
    integer(c_int), parameter :: CU_EVENT_SCHED_YIELD = 2
    integer(c_int), parameter :: CU_EVENT_SCHED_BLOCKING_SYNC = 4

    ! ---- cl_event_flags
    integer(c_int), parameter :: NVCL_EVENT_SCHED_AUTO = 0
    integer(c_int), parameter :: NVCL_EVENT_SCHED_SPIN = 1
    integer(c_int), parameter :: NVCL_EVENT_SCHED_YIELD = 2
    integer(c_int), parameter :: NVCL_EVENT_SCHED_BLOCKING_SYNC = 4

    ! ---- cl_context_flags
    integer(c_int), parameter :: NVCL_CTX_SCHED_AUTO = 0
    integer(c_int), parameter :: NVCL_CTX_SCHED_SPIN = 1
    integer(c_int), parameter :: NVCL_CTX_SCHED_YIELD = 2
    integer(c_int), parameter :: NVCL_CTX_SCHED_BLOCKING_SYNC = 4

    ! ---- CUstream_flags
    integer(c_int), parameter :: CU_STREAM_DEFAULT = 0
    integer(c_int), parameter :: CU_STREAM_NON_BLOCKING = 1

    ! ---- CUevent_flags
    integer(c_int), parameter :: CU_EVENT_DEFAULT = 0
    integer(c_int), parameter :: CU_EVENT_BLOCKING_SYNC = 1
    integer(c_int), parameter :: CU_EVENT_DISABLE_TIMING = 2
    integer(c_int), parameter :: CU_EVENT_INTERPROCESS = 4

    ! ---- CUevent_record_flags
    integer(c_int), parameter :: CU_EVENT_RECORD_DEFAULT = 0
    integer(c_int), parameter :: CU_EVENT_RECORD_EXTERNAL = 1

    ! ---- CUevent_wait_flags
    integer(c_int), parameter :: CU_EVENT_WAIT_DEFAULT = 0
    integer(c_int), parameter :: CU_EVENT_WAIT_EXTERNAL = 1

    ! ---- CUstreamWaitValue_flags
    integer(c_int), parameter :: CU_STREAM_WAIT_VALUE_GEQ = 0
    integer(c_int), parameter :: CU_STREAM_WAIT_VALUE_EQ = 1
    integer(c_int), parameter :: CU_STREAM_WAIT_VALUE_AND = 2
    integer(c_int), parameter :: CU_STREAM_WAIT_VALUE_NOR = 3
    integer(c_int), parameter :: CU_STREAM_WAIT_VALUE_FLUSH = 1073741824

    ! ---- CUstreamWriteValue_flags
    integer(c_int), parameter :: CU_STREAM_WRITE_VALUE_DEFAULT = 0
    integer(c_int), parameter :: CU_STREAM_WRITE_VALUE_NO_MEMORY_BARRIER = 1

    ! ---- CUstreamBatchMemOpType
    integer(c_int), parameter :: CU_STREAM_MEM_OP_WAIT_VALUE_32 = 1
    integer(c_int), parameter :: CU_STREAM_MEM_OP_WRITE_VALUE_32 = 2
    integer(c_int), parameter :: CU_STREAM_MEM_OP_WAIT_VALUE_64 = 4
    integer(c_int), parameter :: CU_STREAM_MEM_OP_WRITE_VALUE_64 = 5
    integer(c_int), parameter :: CU_STREAM_MEM_OP_BARRIER = 6
    integer(c_int), parameter :: CU_STREAM_MEM_OP_FLUSH_REMOTE_WRITES = 3

    ! ---- CUstreamMemoryBarrier_flags
    integer(c_int), parameter :: CU_STREAM_MEMORY_BARRIER_TYPE_SYS = 0
    integer(c_int), parameter :: CU_STREAM_MEMORY_BARRIER_TYPE_GPU = 1

    ! ---- CUoccupancy_flags
    integer(c_int), parameter :: CU_OCCUPANCY_DEFAULT = 0
    integer(c_int), parameter :: CU_OCCUPANCY_DISABLE_CACHING_OVERRIDE = 1

    ! ---- CUstreamUpdateCaptureDependencies_flags
    integer(c_int), parameter :: CU_STREAM_ADD_CAPTURE_DEPENDENCIES = 0
    integer(c_int), parameter :: CU_STREAM_SET_CAPTURE_DEPENDENCIES = 1

    ! ---- CUasyncNotificationType
    integer(c_int), parameter :: CU_ASYNC_NOTIFICATION_TYPE_OVER_BUDGET = 1

    ! ---- CUarray_format
    integer(c_int), parameter :: CU_AD_FORMAT_UNSIGNED_INT8 = 1
    integer(c_int), parameter :: CU_AD_FORMAT_UNSIGNED_INT16 = 2
    integer(c_int), parameter :: CU_AD_FORMAT_UNSIGNED_INT32 = 3
    integer(c_int), parameter :: CU_AD_FORMAT_SIGNED_INT8 = 8
    integer(c_int), parameter :: CU_AD_FORMAT_SIGNED_INT16 = 9
    integer(c_int), parameter :: CU_AD_FORMAT_SIGNED_INT32 = 10
    integer(c_int), parameter :: CU_AD_FORMAT_HALF = 16
    integer(c_int), parameter :: CU_AD_FORMAT_FLOAT = 32
    integer(c_int), parameter :: CU_AD_FORMAT_NV12 = 176
    integer(c_int), parameter :: CU_AD_FORMAT_UNORM_INT8X1 = 192
    integer(c_int), parameter :: CU_AD_FORMAT_UNORM_INT8X2 = 193
    integer(c_int), parameter :: CU_AD_FORMAT_UNORM_INT8X4 = 194
    integer(c_int), parameter :: CU_AD_FORMAT_UNORM_INT16X1 = 195
    integer(c_int), parameter :: CU_AD_FORMAT_UNORM_INT16X2 = 196
    integer(c_int), parameter :: CU_AD_FORMAT_UNORM_INT16X4 = 197
    integer(c_int), parameter :: CU_AD_FORMAT_SNORM_INT8X1 = 198
    integer(c_int), parameter :: CU_AD_FORMAT_SNORM_INT8X2 = 199
    integer(c_int), parameter :: CU_AD_FORMAT_SNORM_INT8X4 = 200
    integer(c_int), parameter :: CU_AD_FORMAT_SNORM_INT16X1 = 201
    integer(c_int), parameter :: CU_AD_FORMAT_SNORM_INT16X2 = 202
    integer(c_int), parameter :: CU_AD_FORMAT_SNORM_INT16X4 = 203
    integer(c_int), parameter :: CU_AD_FORMAT_BC1_UNORM = 145
    integer(c_int), parameter :: CU_AD_FORMAT_BC1_UNORM_SRGB = 146
    integer(c_int), parameter :: CU_AD_FORMAT_BC2_UNORM = 147
    integer(c_int), parameter :: CU_AD_FORMAT_BC2_UNORM_SRGB = 148
    integer(c_int), parameter :: CU_AD_FORMAT_BC3_UNORM = 149
    integer(c_int), parameter :: CU_AD_FORMAT_BC3_UNORM_SRGB = 150
    integer(c_int), parameter :: CU_AD_FORMAT_BC4_UNORM = 151
    integer(c_int), parameter :: CU_AD_FORMAT_BC4_SNORM = 152
    integer(c_int), parameter :: CU_AD_FORMAT_BC5_UNORM = 153
    integer(c_int), parameter :: CU_AD_FORMAT_BC5_SNORM = 154
    integer(c_int), parameter :: CU_AD_FORMAT_BC6H_UF16 = 155
    integer(c_int), parameter :: CU_AD_FORMAT_BC6H_SF16 = 156
    integer(c_int), parameter :: CU_AD_FORMAT_BC7_UNORM = 157
    integer(c_int), parameter :: CU_AD_FORMAT_BC7_UNORM_SRGB = 158
    integer(c_int), parameter :: CU_AD_FORMAT_P010 = 159
    integer(c_int), parameter :: CU_AD_FORMAT_P016 = 161
    integer(c_int), parameter :: CU_AD_FORMAT_NV16 = 162
    integer(c_int), parameter :: CU_AD_FORMAT_P210 = 163
    integer(c_int), parameter :: CU_AD_FORMAT_P216 = 164
    integer(c_int), parameter :: CU_AD_FORMAT_YUY2 = 165
    integer(c_int), parameter :: CU_AD_FORMAT_Y210 = 166
    integer(c_int), parameter :: CU_AD_FORMAT_Y216 = 167
    integer(c_int), parameter :: CU_AD_FORMAT_AYUV = 168
    integer(c_int), parameter :: CU_AD_FORMAT_Y410 = 169
    integer(c_int), parameter :: CU_AD_FORMAT_Y416 = 177
    integer(c_int), parameter :: CU_AD_FORMAT_Y444_PLANAR8 = 178
    integer(c_int), parameter :: CU_AD_FORMAT_Y444_PLANAR10 = 179
    integer(c_int), parameter :: CU_AD_FORMAT_YUV444_8bit_SemiPlanar = 180
    integer(c_int), parameter :: CU_AD_FORMAT_YUV444_16bit_SemiPlanar = 181
    integer(c_int), parameter :: CU_AD_FORMAT_UNORM_INT_101010_2 = 80
    integer(c_int), parameter :: CU_AD_FORMAT_MAX = 2147483647

    ! ---- CUaddress_mode
    integer(c_int), parameter :: CU_TR_ADDRESS_MODE_WRAP = 0
    integer(c_int), parameter :: CU_TR_ADDRESS_MODE_CLAMP = 1
    integer(c_int), parameter :: CU_TR_ADDRESS_MODE_MIRROR = 2
    integer(c_int), parameter :: CU_TR_ADDRESS_MODE_BORDER = 3

    ! ---- CUfilter_mode
    integer(c_int), parameter :: CU_TR_FILTER_MODE_POINT = 0
    integer(c_int), parameter :: CU_TR_FILTER_MODE_LINEAR = 1

    ! ---- CUdevice_attribute
    integer(c_int), parameter :: CU_DEVICE_ATTRIBUTE_MAX_THREADS_PER_BLOCK = 1
    integer(c_int), parameter :: CU_DEVICE_ATTRIBUTE_MAX_BLOCK_DIM_X = 2
    integer(c_int), parameter :: CU_DEVICE_ATTRIBUTE_MAX_BLOCK_DIM_Y = 3
    integer(c_int), parameter :: CU_DEVICE_ATTRIBUTE_MAX_BLOCK_DIM_Z = 4
    integer(c_int), parameter :: CU_DEVICE_ATTRIBUTE_MAX_GRID_DIM_X = 5
    integer(c_int), parameter :: CU_DEVICE_ATTRIBUTE_MAX_GRID_DIM_Y = 6
    integer(c_int), parameter :: CU_DEVICE_ATTRIBUTE_MAX_GRID_DIM_Z = 7
    integer(c_int), parameter :: CU_DEVICE_ATTRIBUTE_MAX_SHARED_MEMORY_PER_BLOCK = 8
    integer(c_int), parameter :: CU_DEVICE_ATTRIBUTE_SHARED_MEMORY_PER_BLOCK = 8
    integer(c_int), parameter :: CU_DEVICE_ATTRIBUTE_TOTAL_CONSTANT_MEMORY = 9
    integer(c_int), parameter :: CU_DEVICE_ATTRIBUTE_WARP_SIZE = 10
    integer(c_int), parameter :: CU_DEVICE_ATTRIBUTE_MAX_PITCH = 11
    integer(c_int), parameter :: CU_DEVICE_ATTRIBUTE_MAX_REGISTERS_PER_BLOCK = 12
    integer(c_int), parameter :: CU_DEVICE_ATTRIBUTE_REGISTERS_PER_BLOCK = 12
    integer(c_int), parameter :: CU_DEVICE_ATTRIBUTE_CLOCK_RATE = 13
    integer(c_int), parameter :: CU_DEVICE_ATTRIBUTE_TEXTURE_ALIGNMENT = 14
    integer(c_int), parameter :: CU_DEVICE_ATTRIBUTE_GPU_OVERLAP = 15
    integer(c_int), parameter :: CU_DEVICE_ATTRIBUTE_MULTIPROCESSOR_COUNT = 16
    integer(c_int), parameter :: CU_DEVICE_ATTRIBUTE_KERNEL_EXEC_TIMEOUT = 17
    integer(c_int), parameter :: CU_DEVICE_ATTRIBUTE_INTEGRATED = 18
    integer(c_int), parameter :: CU_DEVICE_ATTRIBUTE_CAN_MAP_HOST_MEMORY = 19
    integer(c_int), parameter :: CU_DEVICE_ATTRIBUTE_COMPUTE_MODE = 20
    integer(c_int), parameter :: CU_DEVICE_ATTRIBUTE_MAXIMUM_TEXTURE1D_WIDTH = 21
    integer(c_int), parameter :: CU_DEVICE_ATTRIBUTE_MAXIMUM_TEXTURE2D_WIDTH = 22
    integer(c_int), parameter :: CU_DEVICE_ATTRIBUTE_MAXIMUM_TEXTURE2D_HEIGHT = 23
    integer(c_int), parameter :: CU_DEVICE_ATTRIBUTE_MAXIMUM_TEXTURE3D_WIDTH = 24
    integer(c_int), parameter :: CU_DEVICE_ATTRIBUTE_MAXIMUM_TEXTURE3D_HEIGHT = 25
    integer(c_int), parameter :: CU_DEVICE_ATTRIBUTE_MAXIMUM_TEXTURE3D_DEPTH = 26
    integer(c_int), parameter :: CU_DEVICE_ATTRIBUTE_MAXIMUM_TEXTURE2D_LAYERED_WIDTH = 27
    integer(c_int), parameter :: CU_DEVICE_ATTRIBUTE_MAXIMUM_TEXTURE2D_LAYERED_HEIGHT = 28
    integer(c_int), parameter :: CU_DEVICE_ATTRIBUTE_MAXIMUM_TEXTURE2D_LAYERED_LAYERS = 29
    integer(c_int), parameter :: CU_DEVICE_ATTRIBUTE_MAXIMUM_TEXTURE2D_ARRAY_WIDTH = 27
    integer(c_int), parameter :: CU_DEVICE_ATTRIBUTE_MAXIMUM_TEXTURE2D_ARRAY_HEIGHT = 28
    integer(c_int), parameter :: CU_DEVICE_ATTRIBUTE_MAXIMUM_TEXTURE2D_ARRAY_NUMSLICES = 29
    integer(c_int), parameter :: CU_DEVICE_ATTRIBUTE_SURFACE_ALIGNMENT = 30
    integer(c_int), parameter :: CU_DEVICE_ATTRIBUTE_CONCURRENT_KERNELS = 31
    integer(c_int), parameter :: CU_DEVICE_ATTRIBUTE_ECC_ENABLED = 32
    integer(c_int), parameter :: CU_DEVICE_ATTRIBUTE_PCI_BUS_ID = 33
    integer(c_int), parameter :: CU_DEVICE_ATTRIBUTE_PCI_DEVICE_ID = 34
    integer(c_int), parameter :: CU_DEVICE_ATTRIBUTE_TCC_DRIVER = 35
    integer(c_int), parameter :: CU_DEVICE_ATTRIBUTE_MEMORY_CLOCK_RATE = 36
    integer(c_int), parameter :: CU_DEVICE_ATTRIBUTE_GLOBAL_MEMORY_BUS_WIDTH = 37
    integer(c_int), parameter :: CU_DEVICE_ATTRIBUTE_L2_CACHE_SIZE = 38
    integer(c_int), parameter :: CU_DEVICE_ATTRIBUTE_MAX_THREADS_PER_MULTIPROCESSOR = 39
    integer(c_int), parameter :: CU_DEVICE_ATTRIBUTE_ASYNC_ENGINE_COUNT = 40
    integer(c_int), parameter :: CU_DEVICE_ATTRIBUTE_UNIFIED_ADDRESSING = 41
    integer(c_int), parameter :: CU_DEVICE_ATTRIBUTE_MAXIMUM_TEXTURE1D_LAYERED_WIDTH = 42
    integer(c_int), parameter :: CU_DEVICE_ATTRIBUTE_MAXIMUM_TEXTURE1D_LAYERED_LAYERS = 43
    integer(c_int), parameter :: CU_DEVICE_ATTRIBUTE_CAN_TEX2D_GATHER = 44
    integer(c_int), parameter :: CU_DEVICE_ATTRIBUTE_MAXIMUM_TEXTURE2D_GATHER_WIDTH = 45
    integer(c_int), parameter :: CU_DEVICE_ATTRIBUTE_MAXIMUM_TEXTURE2D_GATHER_HEIGHT = 46
    integer(c_int), parameter :: CU_DEVICE_ATTRIBUTE_MAXIMUM_TEXTURE3D_WIDTH_ALTERNATE = 47
    integer(c_int), parameter :: CU_DEVICE_ATTRIBUTE_MAXIMUM_TEXTURE3D_HEIGHT_ALTERNATE = 48
    integer(c_int), parameter :: CU_DEVICE_ATTRIBUTE_MAXIMUM_TEXTURE3D_DEPTH_ALTERNATE = 49
    integer(c_int), parameter :: CU_DEVICE_ATTRIBUTE_PCI_DOMAIN_ID = 50
    integer(c_int), parameter :: CU_DEVICE_ATTRIBUTE_TEXTURE_PITCH_ALIGNMENT = 51
    integer(c_int), parameter :: CU_DEVICE_ATTRIBUTE_MAXIMUM_TEXTURECUBEMAP_WIDTH = 52
    integer(c_int), parameter :: CU_DEVICE_ATTRIBUTE_MAXIMUM_TEXTURECUBEMAP_LAYERED_WIDTH = 53
    integer(c_int), parameter :: CU_DEVICE_ATTRIBUTE_MAXIMUM_TEXTURECUBEMAP_LAYERED_LAYERS = 54
    integer(c_int), parameter :: CU_DEVICE_ATTRIBUTE_MAXIMUM_SURFACE1D_WIDTH = 55
    integer(c_int), parameter :: CU_DEVICE_ATTRIBUTE_MAXIMUM_SURFACE2D_WIDTH = 56
    integer(c_int), parameter :: CU_DEVICE_ATTRIBUTE_MAXIMUM_SURFACE2D_HEIGHT = 57
    integer(c_int), parameter :: CU_DEVICE_ATTRIBUTE_MAXIMUM_SURFACE3D_WIDTH = 58
    integer(c_int), parameter :: CU_DEVICE_ATTRIBUTE_MAXIMUM_SURFACE3D_HEIGHT = 59
    integer(c_int), parameter :: CU_DEVICE_ATTRIBUTE_MAXIMUM_SURFACE3D_DEPTH = 60
    integer(c_int), parameter :: CU_DEVICE_ATTRIBUTE_MAXIMUM_SURFACE1D_LAYERED_WIDTH = 61
    integer(c_int), parameter :: CU_DEVICE_ATTRIBUTE_MAXIMUM_SURFACE1D_LAYERED_LAYERS = 62
    integer(c_int), parameter :: CU_DEVICE_ATTRIBUTE_MAXIMUM_SURFACE2D_LAYERED_WIDTH = 63
    integer(c_int), parameter :: CU_DEVICE_ATTRIBUTE_MAXIMUM_SURFACE2D_LAYERED_HEIGHT = 64
    integer(c_int), parameter :: CU_DEVICE_ATTRIBUTE_MAXIMUM_SURFACE2D_LAYERED_LAYERS = 65
    integer(c_int), parameter :: CU_DEVICE_ATTRIBUTE_MAXIMUM_SURFACECUBEMAP_WIDTH = 66
    integer(c_int), parameter :: CU_DEVICE_ATTRIBUTE_MAXIMUM_SURFACECUBEMAP_LAYERED_WIDTH = 67
    integer(c_int), parameter :: CU_DEVICE_ATTRIBUTE_MAXIMUM_SURFACECUBEMAP_LAYERED_LAYERS = 68
    integer(c_int), parameter :: CU_DEVICE_ATTRIBUTE_MAXIMUM_TEXTURE1D_LINEAR_WIDTH = 69
    integer(c_int), parameter :: CU_DEVICE_ATTRIBUTE_MAXIMUM_TEXTURE2D_LINEAR_WIDTH = 70
    integer(c_int), parameter :: CU_DEVICE_ATTRIBUTE_MAXIMUM_TEXTURE2D_LINEAR_HEIGHT = 71
    integer(c_int), parameter :: CU_DEVICE_ATTRIBUTE_MAXIMUM_TEXTURE2D_LINEAR_PITCH = 72
    integer(c_int), parameter :: CU_DEVICE_ATTRIBUTE_MAXIMUM_TEXTURE2D_MIPMAPPED_WIDTH = 73
    integer(c_int), parameter :: CU_DEVICE_ATTRIBUTE_MAXIMUM_TEXTURE2D_MIPMAPPED_HEIGHT = 74
    integer(c_int), parameter :: CU_DEVICE_ATTRIBUTE_COMPUTE_CAPABILITY_MAJOR = 75
    integer(c_int), parameter :: CU_DEVICE_ATTRIBUTE_COMPUTE_CAPABILITY_MINOR = 76
    integer(c_int), parameter :: CU_DEVICE_ATTRIBUTE_MAXIMUM_TEXTURE1D_MIPMAPPED_WIDTH = 77
    integer(c_int), parameter :: CU_DEVICE_ATTRIBUTE_STREAM_PRIORITIES_SUPPORTED = 78
    integer(c_int), parameter :: CU_DEVICE_ATTRIBUTE_GLOBAL_L1_CACHE_SUPPORTED = 79
    integer(c_int), parameter :: CU_DEVICE_ATTRIBUTE_LOCAL_L1_CACHE_SUPPORTED = 80
    integer(c_int), parameter :: CU_DEVICE_ATTRIBUTE_MAX_SHARED_MEMORY_PER_MULTIPROCESSOR = 81
    integer(c_int), parameter :: CU_DEVICE_ATTRIBUTE_MAX_REGISTERS_PER_MULTIPROCESSOR = 82
    integer(c_int), parameter :: CU_DEVICE_ATTRIBUTE_MANAGED_MEMORY = 83
    integer(c_int), parameter :: CU_DEVICE_ATTRIBUTE_MULTI_GPU_BOARD = 84
    integer(c_int), parameter :: CU_DEVICE_ATTRIBUTE_MULTI_GPU_BOARD_GROUP_ID = 85
    integer(c_int), parameter :: CU_DEVICE_ATTRIBUTE_HOST_NATIVE_ATOMIC_SUPPORTED = 86
    integer(c_int), parameter :: CU_DEVICE_ATTRIBUTE_SINGLE_TO_DOUBLE_PRECISION_PERF_RATIO = 87
    integer(c_int), parameter :: CU_DEVICE_ATTRIBUTE_PAGEABLE_MEMORY_ACCESS = 88
    integer(c_int), parameter :: CU_DEVICE_ATTRIBUTE_CONCURRENT_MANAGED_ACCESS = 89
    integer(c_int), parameter :: CU_DEVICE_ATTRIBUTE_COMPUTE_PREEMPTION_SUPPORTED = 90
    integer(c_int), parameter :: CU_DEVICE_ATTRIBUTE_CAN_USE_HOST_POINTER_FOR_REGISTERED_MEM = 91
    integer(c_int), parameter :: CU_DEVICE_ATTRIBUTE_CAN_USE_STREAM_MEM_OPS_V1 = 92
    integer(c_int), parameter :: CU_DEVICE_ATTRIBUTE_CAN_USE_64_BIT_STREAM_MEM_OPS_V1 = 93
    integer(c_int), parameter :: CU_DEVICE_ATTRIBUTE_CAN_USE_STREAM_WAIT_VALUE_NOR_V1 = 94
    integer(c_int), parameter :: CU_DEVICE_ATTRIBUTE_COOPERATIVE_LAUNCH = 95
    integer(c_int), parameter :: CU_DEVICE_ATTRIBUTE_COOPERATIVE_MULTI_DEVICE_LAUNCH = 96
    integer(c_int), parameter :: CU_DEVICE_ATTRIBUTE_MAX_SHARED_MEMORY_PER_BLOCK_OPTIN = 97
    integer(c_int), parameter :: CU_DEVICE_ATTRIBUTE_CAN_FLUSH_REMOTE_WRITES = 98
    integer(c_int), parameter :: CU_DEVICE_ATTRIBUTE_HOST_REGISTER_SUPPORTED = 99
    ! C name (shortened to fit Fortran's 63-char limit): CU_DEVICE_ATTRIBUTE_PAGEABLE_MEMORY_ACCESS_USES_HOST_PAGE_TABLES
    integer(c_int), parameter :: CU_DEV_ATTR_PAGEABLE_MEMORY_ACCESS_USES_HOST_PAGE_TABLES = 100
    integer(c_int), parameter :: CU_DEVICE_ATTRIBUTE_DIRECT_MANAGED_MEM_ACCESS_FROM_HOST = 101
    integer(c_int), parameter :: CU_DEVICE_ATTRIBUTE_VIRTUAL_ADDRESS_MANAGEMENT_SUPPORTED = 102
    integer(c_int), parameter :: CU_DEVICE_ATTRIBUTE_VIRTUAL_MEMORY_MANAGEMENT_SUPPORTED = 102
    integer(c_int), parameter :: CU_DEVICE_ATTRIBUTE_HANDLE_TYPE_POSIX_FILE_DESCRIPTOR_SUPPORTED = 103
    integer(c_int), parameter :: CU_DEVICE_ATTRIBUTE_HANDLE_TYPE_WIN32_HANDLE_SUPPORTED = 104
    integer(c_int), parameter :: CU_DEVICE_ATTRIBUTE_HANDLE_TYPE_WIN32_KMT_HANDLE_SUPPORTED = 105
    integer(c_int), parameter :: CU_DEVICE_ATTRIBUTE_MAX_BLOCKS_PER_MULTIPROCESSOR = 106
    integer(c_int), parameter :: CU_DEVICE_ATTRIBUTE_GENERIC_COMPRESSION_SUPPORTED = 107
    integer(c_int), parameter :: CU_DEVICE_ATTRIBUTE_MAX_PERSISTING_L2_CACHE_SIZE = 108
    integer(c_int), parameter :: CU_DEVICE_ATTRIBUTE_MAX_ACCESS_POLICY_WINDOW_SIZE = 109
    integer(c_int), parameter :: CU_DEVICE_ATTRIBUTE_GPU_DIRECT_RDMA_WITH_CUDA_VMM_SUPPORTED = 110
    integer(c_int), parameter :: CU_DEVICE_ATTRIBUTE_RESERVED_SHARED_MEMORY_PER_BLOCK = 111
    integer(c_int), parameter :: CU_DEVICE_ATTRIBUTE_SPARSE_CUDA_ARRAY_SUPPORTED = 112
    integer(c_int), parameter :: CU_DEVICE_ATTRIBUTE_READ_ONLY_HOST_REGISTER_SUPPORTED = 113
    integer(c_int), parameter :: CU_DEVICE_ATTRIBUTE_TIMELINE_SEMAPHORE_INTEROP_SUPPORTED = 114
    integer(c_int), parameter :: CU_DEVICE_ATTRIBUTE_MEMORY_POOLS_SUPPORTED = 115
    integer(c_int), parameter :: CU_DEVICE_ATTRIBUTE_GPU_DIRECT_RDMA_SUPPORTED = 116
    integer(c_int), parameter :: CU_DEVICE_ATTRIBUTE_GPU_DIRECT_RDMA_FLUSH_WRITES_OPTIONS = 117
    integer(c_int), parameter :: CU_DEVICE_ATTRIBUTE_GPU_DIRECT_RDMA_WRITES_ORDERING = 118
    integer(c_int), parameter :: CU_DEVICE_ATTRIBUTE_MEMPOOL_SUPPORTED_HANDLE_TYPES = 119
    integer(c_int), parameter :: CU_DEVICE_ATTRIBUTE_CLUSTER_LAUNCH = 120
    integer(c_int), parameter :: CU_DEVICE_ATTRIBUTE_DEFERRED_MAPPING_CUDA_ARRAY_SUPPORTED = 121
    integer(c_int), parameter :: CU_DEVICE_ATTRIBUTE_CAN_USE_64_BIT_STREAM_MEM_OPS = 122
    integer(c_int), parameter :: CU_DEVICE_ATTRIBUTE_CAN_USE_STREAM_WAIT_VALUE_NOR = 123
    integer(c_int), parameter :: CU_DEVICE_ATTRIBUTE_DMA_BUF_SUPPORTED = 124
    integer(c_int), parameter :: CU_DEVICE_ATTRIBUTE_IPC_EVENT_SUPPORTED = 125
    integer(c_int), parameter :: CU_DEVICE_ATTRIBUTE_MEM_SYNC_DOMAIN_COUNT = 126
    integer(c_int), parameter :: CU_DEVICE_ATTRIBUTE_TENSOR_MAP_ACCESS_SUPPORTED = 127
    integer(c_int), parameter :: CU_DEVICE_ATTRIBUTE_HANDLE_TYPE_FABRIC_SUPPORTED = 128
    integer(c_int), parameter :: CU_DEVICE_ATTRIBUTE_UNIFIED_FUNCTION_POINTERS = 129
    integer(c_int), parameter :: CU_DEVICE_ATTRIBUTE_NUMA_CONFIG = 130
    integer(c_int), parameter :: CU_DEVICE_ATTRIBUTE_NUMA_ID = 131
    integer(c_int), parameter :: CU_DEVICE_ATTRIBUTE_MULTICAST_SUPPORTED = 132
    integer(c_int), parameter :: CU_DEVICE_ATTRIBUTE_MPS_ENABLED = 133
    integer(c_int), parameter :: CU_DEVICE_ATTRIBUTE_HOST_NUMA_ID = 134
    integer(c_int), parameter :: CU_DEVICE_ATTRIBUTE_D3D12_CIG_SUPPORTED = 135
    integer(c_int), parameter :: CU_DEVICE_ATTRIBUTE_MEM_DECOMPRESS_ALGORITHM_MASK = 136
    integer(c_int), parameter :: CU_DEVICE_ATTRIBUTE_MEM_DECOMPRESS_MAXIMUM_LENGTH = 137
    integer(c_int), parameter :: CU_DEVICE_ATTRIBUTE_VULKAN_CIG_SUPPORTED = 138
    integer(c_int), parameter :: CU_DEVICE_ATTRIBUTE_GPU_PCI_DEVICE_ID = 139
    integer(c_int), parameter :: CU_DEVICE_ATTRIBUTE_GPU_PCI_SUBSYSTEM_ID = 140
    ! C name (shortened to fit Fortran's 63-char limit): CU_DEVICE_ATTRIBUTE_HOST_NUMA_VIRTUAL_MEMORY_MANAGEMENT_SUPPORTED
    integer(c_int), parameter :: CU_DEV_ATTR_HOST_NUMA_VIRTUAL_MEMORY_MANAGEMENT_SUPPORTED = 141
    integer(c_int), parameter :: CU_DEVICE_ATTRIBUTE_HOST_NUMA_MEMORY_POOLS_SUPPORTED = 142
    integer(c_int), parameter :: CU_DEVICE_ATTRIBUTE_HOST_NUMA_MULTINODE_IPC_SUPPORTED = 143
    integer(c_int), parameter :: CU_DEVICE_ATTRIBUTE_MAX = 144

    ! ---- CUpointer_attribute
    integer(c_int), parameter :: CU_POINTER_ATTRIBUTE_CONTEXT = 1
    integer(c_int), parameter :: CU_POINTER_ATTRIBUTE_MEMORY_TYPE = 2
    integer(c_int), parameter :: CU_POINTER_ATTRIBUTE_DEVICE_POINTER = 3
    integer(c_int), parameter :: CU_POINTER_ATTRIBUTE_HOST_POINTER = 4
    integer(c_int), parameter :: CU_POINTER_ATTRIBUTE_P2P_TOKENS = 5
    integer(c_int), parameter :: CU_POINTER_ATTRIBUTE_SYNC_MEMOPS = 6
    integer(c_int), parameter :: CU_POINTER_ATTRIBUTE_BUFFER_ID = 7
    integer(c_int), parameter :: CU_POINTER_ATTRIBUTE_IS_MANAGED = 8
    integer(c_int), parameter :: CU_POINTER_ATTRIBUTE_DEVICE_ORDINAL = 9
    integer(c_int), parameter :: CU_POINTER_ATTRIBUTE_IS_LEGACY_CUDA_IPC_CAPABLE = 10
    integer(c_int), parameter :: CU_POINTER_ATTRIBUTE_RANGE_START_ADDR = 11
    integer(c_int), parameter :: CU_POINTER_ATTRIBUTE_RANGE_SIZE = 12
    integer(c_int), parameter :: CU_POINTER_ATTRIBUTE_MAPPED = 13
    integer(c_int), parameter :: CU_POINTER_ATTRIBUTE_ALLOWED_HANDLE_TYPES = 14
    integer(c_int), parameter :: CU_POINTER_ATTRIBUTE_IS_GPU_DIRECT_RDMA_CAPABLE = 15
    integer(c_int), parameter :: CU_POINTER_ATTRIBUTE_ACCESS_FLAGS = 16
    integer(c_int), parameter :: CU_POINTER_ATTRIBUTE_MEMPOOL_HANDLE = 17
    integer(c_int), parameter :: CU_POINTER_ATTRIBUTE_MAPPING_SIZE = 18
    integer(c_int), parameter :: CU_POINTER_ATTRIBUTE_MAPPING_BASE_ADDR = 19
    integer(c_int), parameter :: CU_POINTER_ATTRIBUTE_MEMORY_BLOCK_ID = 20
    integer(c_int), parameter :: CU_POINTER_ATTRIBUTE_IS_HW_DECOMPRESS_CAPABLE = 21

    ! ---- CUfunction_attribute
    integer(c_int), parameter :: CU_FUNC_ATTRIBUTE_MAX_THREADS_PER_BLOCK = 0
    integer(c_int), parameter :: CU_FUNC_ATTRIBUTE_SHARED_SIZE_BYTES = 1
    integer(c_int), parameter :: CU_FUNC_ATTRIBUTE_CONST_SIZE_BYTES = 2
    integer(c_int), parameter :: CU_FUNC_ATTRIBUTE_LOCAL_SIZE_BYTES = 3
    integer(c_int), parameter :: CU_FUNC_ATTRIBUTE_NUM_REGS = 4
    integer(c_int), parameter :: CU_FUNC_ATTRIBUTE_PTX_VERSION = 5
    integer(c_int), parameter :: CU_FUNC_ATTRIBUTE_BINARY_VERSION = 6
    integer(c_int), parameter :: CU_FUNC_ATTRIBUTE_CACHE_MODE_CA = 7
    integer(c_int), parameter :: CU_FUNC_ATTRIBUTE_MAX_DYNAMIC_SHARED_SIZE_BYTES = 8
    integer(c_int), parameter :: CU_FUNC_ATTRIBUTE_PREFERRED_SHARED_MEMORY_CARVEOUT = 9
    integer(c_int), parameter :: CU_FUNC_ATTRIBUTE_CLUSTER_SIZE_MUST_BE_SET = 10
    integer(c_int), parameter :: CU_FUNC_ATTRIBUTE_REQUIRED_CLUSTER_WIDTH = 11
    integer(c_int), parameter :: CU_FUNC_ATTRIBUTE_REQUIRED_CLUSTER_HEIGHT = 12
    integer(c_int), parameter :: CU_FUNC_ATTRIBUTE_REQUIRED_CLUSTER_DEPTH = 13
    integer(c_int), parameter :: CU_FUNC_ATTRIBUTE_NON_PORTABLE_CLUSTER_SIZE_ALLOWED = 14
    integer(c_int), parameter :: CU_FUNC_ATTRIBUTE_CLUSTER_SCHEDULING_POLICY_PREFERENCE = 15
    integer(c_int), parameter :: CU_FUNC_ATTRIBUTE_MAX = 16

    ! ---- CUfunc_cache
    integer(c_int), parameter :: CU_FUNC_CACHE_PREFER_NONE = 0
    integer(c_int), parameter :: CU_FUNC_CACHE_PREFER_SHARED = 1
    integer(c_int), parameter :: CU_FUNC_CACHE_PREFER_L1 = 2
    integer(c_int), parameter :: CU_FUNC_CACHE_PREFER_EQUAL = 3

    ! ---- CUsharedconfig
    integer(c_int), parameter :: CU_SHARED_MEM_CONFIG_DEFAULT_BANK_SIZE = 0
    integer(c_int), parameter :: CU_SHARED_MEM_CONFIG_FOUR_BYTE_BANK_SIZE = 1
    integer(c_int), parameter :: CU_SHARED_MEM_CONFIG_EIGHT_BYTE_BANK_SIZE = 2

    ! ---- CUshared_carveout
    integer(c_int), parameter :: CU_SHAREDMEM_CARVEOUT_DEFAULT = -1
    integer(c_int), parameter :: CU_SHAREDMEM_CARVEOUT_MAX_SHARED = 100
    integer(c_int), parameter :: CU_SHAREDMEM_CARVEOUT_MAX_L1 = 0

    ! ---- CUmemorytype
    integer(c_int), parameter :: CU_MEMORYTYPE_HOST = 1
    integer(c_int), parameter :: CU_MEMORYTYPE_DEVICE = 2
    integer(c_int), parameter :: CU_MEMORYTYPE_ARRAY = 3
    integer(c_int), parameter :: CU_MEMORYTYPE_UNIFIED = 4

    ! ---- CUcomputemode
    integer(c_int), parameter :: CU_COMPUTEMODE_DEFAULT = 0
    integer(c_int), parameter :: CU_COMPUTEMODE_PROHIBITED = 2
    integer(c_int), parameter :: CU_COMPUTEMODE_EXCLUSIVE_PROCESS = 3

    ! ---- CUmem_advise
    integer(c_int), parameter :: CU_MEM_ADVISE_SET_READ_MOSTLY = 1
    integer(c_int), parameter :: CU_MEM_ADVISE_UNSET_READ_MOSTLY = 2
    integer(c_int), parameter :: CU_MEM_ADVISE_SET_PREFERRED_LOCATION = 3
    integer(c_int), parameter :: CU_MEM_ADVISE_UNSET_PREFERRED_LOCATION = 4
    integer(c_int), parameter :: CU_MEM_ADVISE_SET_ACCESSED_BY = 5
    integer(c_int), parameter :: CU_MEM_ADVISE_UNSET_ACCESSED_BY = 6

    ! ---- CUmem_range_attribute
    integer(c_int), parameter :: CU_MEM_RANGE_ATTRIBUTE_READ_MOSTLY = 1
    integer(c_int), parameter :: CU_MEM_RANGE_ATTRIBUTE_PREFERRED_LOCATION = 2
    integer(c_int), parameter :: CU_MEM_RANGE_ATTRIBUTE_ACCESSED_BY = 3
    integer(c_int), parameter :: CU_MEM_RANGE_ATTRIBUTE_LAST_PREFETCH_LOCATION = 4
    integer(c_int), parameter :: CU_MEM_RANGE_ATTRIBUTE_PREFERRED_LOCATION_TYPE = 5
    integer(c_int), parameter :: CU_MEM_RANGE_ATTRIBUTE_PREFERRED_LOCATION_ID = 6
    integer(c_int), parameter :: CU_MEM_RANGE_ATTRIBUTE_LAST_PREFETCH_LOCATION_TYPE = 7
    integer(c_int), parameter :: CU_MEM_RANGE_ATTRIBUTE_LAST_PREFETCH_LOCATION_ID = 8

    ! ---- CUjit_option
    integer(c_int), parameter :: CU_JIT_MAX_REGISTERS = 0
    integer(c_int), parameter :: CU_JIT_THREADS_PER_BLOCK = 1
    integer(c_int), parameter :: CU_JIT_WALL_TIME = 2
    integer(c_int), parameter :: CU_JIT_INFO_LOG_BUFFER = 3
    integer(c_int), parameter :: CU_JIT_INFO_LOG_BUFFER_SIZE_BYTES = 4
    integer(c_int), parameter :: CU_JIT_ERROR_LOG_BUFFER = 5
    integer(c_int), parameter :: CU_JIT_ERROR_LOG_BUFFER_SIZE_BYTES = 6
    integer(c_int), parameter :: CU_JIT_OPTIMIZATION_LEVEL = 7
    integer(c_int), parameter :: CU_JIT_TARGET_FROM_CUCONTEXT = 8
    integer(c_int), parameter :: CU_JIT_TARGET = 9
    integer(c_int), parameter :: CU_JIT_FALLBACK_STRATEGY = 10
    integer(c_int), parameter :: CU_JIT_GENERATE_DEBUG_INFO = 11
    integer(c_int), parameter :: CU_JIT_LOG_VERBOSE = 12
    integer(c_int), parameter :: CU_JIT_GENERATE_LINE_INFO = 13
    integer(c_int), parameter :: CU_JIT_CACHE_MODE = 14
    integer(c_int), parameter :: CU_JIT_NEW_SM3X_OPT = 15
    integer(c_int), parameter :: CU_JIT_FAST_COMPILE = 16
    integer(c_int), parameter :: CU_JIT_GLOBAL_SYMBOL_NAMES = 17
    integer(c_int), parameter :: CU_JIT_GLOBAL_SYMBOL_ADDRESSES = 18
    integer(c_int), parameter :: CU_JIT_GLOBAL_SYMBOL_COUNT = 19
    integer(c_int), parameter :: CU_JIT_LTO = 20
    integer(c_int), parameter :: CU_JIT_FTZ = 21
    integer(c_int), parameter :: CU_JIT_PREC_DIV = 22
    integer(c_int), parameter :: CU_JIT_PREC_SQRT = 23
    integer(c_int), parameter :: CU_JIT_FMA = 24
    integer(c_int), parameter :: CU_JIT_REFERENCED_KERNEL_NAMES = 25
    integer(c_int), parameter :: CU_JIT_REFERENCED_KERNEL_COUNT = 26
    integer(c_int), parameter :: CU_JIT_REFERENCED_VARIABLE_NAMES = 27
    integer(c_int), parameter :: CU_JIT_REFERENCED_VARIABLE_COUNT = 28
    integer(c_int), parameter :: CU_JIT_OPTIMIZE_UNUSED_DEVICE_VARIABLES = 29
    integer(c_int), parameter :: CU_JIT_POSITION_INDEPENDENT_CODE = 30
    integer(c_int), parameter :: CU_JIT_MIN_CTA_PER_SM = 31
    integer(c_int), parameter :: CU_JIT_MAX_THREADS_PER_BLOCK = 32
    integer(c_int), parameter :: CU_JIT_OVERRIDE_DIRECTIVE_VALUES = 33
    integer(c_int), parameter :: CU_JIT_NUM_OPTIONS = 34

    ! ---- CUjit_target
    integer(c_int), parameter :: CU_TARGET_COMPUTE_30 = 30
    integer(c_int), parameter :: CU_TARGET_COMPUTE_32 = 32
    integer(c_int), parameter :: CU_TARGET_COMPUTE_35 = 35
    integer(c_int), parameter :: CU_TARGET_COMPUTE_37 = 37
    integer(c_int), parameter :: CU_TARGET_COMPUTE_50 = 50
    integer(c_int), parameter :: CU_TARGET_COMPUTE_52 = 52
    integer(c_int), parameter :: CU_TARGET_COMPUTE_53 = 53
    integer(c_int), parameter :: CU_TARGET_COMPUTE_60 = 60
    integer(c_int), parameter :: CU_TARGET_COMPUTE_61 = 61
    integer(c_int), parameter :: CU_TARGET_COMPUTE_62 = 62
    integer(c_int), parameter :: CU_TARGET_COMPUTE_70 = 70
    integer(c_int), parameter :: CU_TARGET_COMPUTE_72 = 72
    integer(c_int), parameter :: CU_TARGET_COMPUTE_75 = 75
    integer(c_int), parameter :: CU_TARGET_COMPUTE_80 = 80
    integer(c_int), parameter :: CU_TARGET_COMPUTE_86 = 86
    integer(c_int), parameter :: CU_TARGET_COMPUTE_87 = 87
    integer(c_int), parameter :: CU_TARGET_COMPUTE_89 = 89
    integer(c_int), parameter :: CU_TARGET_COMPUTE_90 = 90
    integer(c_int), parameter :: CU_TARGET_COMPUTE_100 = 100
    integer(c_int), parameter :: CU_TARGET_COMPUTE_101 = 101
    integer(c_int), parameter :: CU_TARGET_COMPUTE_103 = 103
    integer(c_int), parameter :: CU_TARGET_COMPUTE_120 = 120
    integer(c_int), parameter :: CU_TARGET_COMPUTE_121 = 121

    ! ---- CUjit_fallback
    integer(c_int), parameter :: CU_PREFER_PTX = 0
    integer(c_int), parameter :: CU_PREFER_BINARY = 1

    ! ---- CUjit_cacheMode
    integer(c_int), parameter :: CU_JIT_CACHE_OPTION_NONE = 0
    integer(c_int), parameter :: CU_JIT_CACHE_OPTION_CG = 1
    integer(c_int), parameter :: CU_JIT_CACHE_OPTION_CA = 2

    ! ---- CUjitInputType
    integer(c_int), parameter :: CU_JIT_INPUT_CUBIN = 0
    integer(c_int), parameter :: CU_JIT_INPUT_PTX = 1
    integer(c_int), parameter :: CU_JIT_INPUT_FATBINARY = 2
    integer(c_int), parameter :: CU_JIT_INPUT_OBJECT = 3
    integer(c_int), parameter :: CU_JIT_INPUT_LIBRARY = 4
    integer(c_int), parameter :: CU_JIT_INPUT_NVVM = 5
    integer(c_int), parameter :: CU_JIT_NUM_INPUT_TYPES = 6

    ! ---- CUgraphicsRegisterFlags
    integer(c_int), parameter :: CU_GRAPHICS_REGISTER_FLAGS_NONE = 0
    integer(c_int), parameter :: CU_GRAPHICS_REGISTER_FLAGS_READ_ONLY = 1
    integer(c_int), parameter :: CU_GRAPHICS_REGISTER_FLAGS_WRITE_DISCARD = 2
    integer(c_int), parameter :: CU_GRAPHICS_REGISTER_FLAGS_SURFACE_LDST = 4
    integer(c_int), parameter :: CU_GRAPHICS_REGISTER_FLAGS_TEXTURE_GATHER = 8

    ! ---- CUgraphicsMapResourceFlags
    integer(c_int), parameter :: CU_GRAPHICS_MAP_RESOURCE_FLAGS_NONE = 0
    integer(c_int), parameter :: CU_GRAPHICS_MAP_RESOURCE_FLAGS_READ_ONLY = 1
    integer(c_int), parameter :: CU_GRAPHICS_MAP_RESOURCE_FLAGS_WRITE_DISCARD = 2

    ! ---- CUarray_cubemap_face
    integer(c_int), parameter :: CU_CUBEMAP_FACE_POSITIVE_X = 0
    integer(c_int), parameter :: CU_CUBEMAP_FACE_NEGATIVE_X = 1
    integer(c_int), parameter :: CU_CUBEMAP_FACE_POSITIVE_Y = 2
    integer(c_int), parameter :: CU_CUBEMAP_FACE_NEGATIVE_Y = 3
    integer(c_int), parameter :: CU_CUBEMAP_FACE_POSITIVE_Z = 4
    integer(c_int), parameter :: CU_CUBEMAP_FACE_NEGATIVE_Z = 5

    ! ---- CUlimit
    integer(c_int), parameter :: CU_LIMIT_STACK_SIZE = 0
    integer(c_int), parameter :: CU_LIMIT_PRINTF_FIFO_SIZE = 1
    integer(c_int), parameter :: CU_LIMIT_MALLOC_HEAP_SIZE = 2
    integer(c_int), parameter :: CU_LIMIT_DEV_RUNTIME_SYNC_DEPTH = 3
    integer(c_int), parameter :: CU_LIMIT_DEV_RUNTIME_PENDING_LAUNCH_COUNT = 4
    integer(c_int), parameter :: CU_LIMIT_MAX_L2_FETCH_GRANULARITY = 5
    integer(c_int), parameter :: CU_LIMIT_PERSISTING_L2_CACHE_SIZE = 6
    integer(c_int), parameter :: CU_LIMIT_SHMEM_SIZE = 7
    integer(c_int), parameter :: CU_LIMIT_CIG_ENABLED = 8
    integer(c_int), parameter :: CU_LIMIT_CIG_SHMEM_FALLBACK_ENABLED = 9
    integer(c_int), parameter :: CU_LIMIT_MAX = 10

    ! ---- CUresourcetype
    integer(c_int), parameter :: CU_RESOURCE_TYPE_ARRAY = 0
    integer(c_int), parameter :: CU_RESOURCE_TYPE_MIPMAPPED_ARRAY = 1
    integer(c_int), parameter :: CU_RESOURCE_TYPE_LINEAR = 2
    integer(c_int), parameter :: CU_RESOURCE_TYPE_PITCH2D = 3

    ! ---- CUaccessProperty
    integer(c_int), parameter :: CU_ACCESS_PROPERTY_NORMAL = 0
    integer(c_int), parameter :: CU_ACCESS_PROPERTY_STREAMING = 1
    integer(c_int), parameter :: CU_ACCESS_PROPERTY_PERSISTING = 2

    ! ---- CUgraphConditionalNodeType
    integer(c_int), parameter :: CU_GRAPH_COND_TYPE_IF = 0
    integer(c_int), parameter :: CU_GRAPH_COND_TYPE_WHILE = 1
    integer(c_int), parameter :: CU_GRAPH_COND_TYPE_SWITCH = 2

    ! ---- CUgraphNodeType
    integer(c_int), parameter :: CU_GRAPH_NODE_TYPE_KERNEL = 0
    integer(c_int), parameter :: CU_GRAPH_NODE_TYPE_MEMCPY = 1
    integer(c_int), parameter :: CU_GRAPH_NODE_TYPE_MEMSET = 2
    integer(c_int), parameter :: CU_GRAPH_NODE_TYPE_HOST = 3
    integer(c_int), parameter :: CU_GRAPH_NODE_TYPE_GRAPH = 4
    integer(c_int), parameter :: CU_GRAPH_NODE_TYPE_EMPTY = 5
    integer(c_int), parameter :: CU_GRAPH_NODE_TYPE_WAIT_EVENT = 6
    integer(c_int), parameter :: CU_GRAPH_NODE_TYPE_EVENT_RECORD = 7
    integer(c_int), parameter :: CU_GRAPH_NODE_TYPE_EXT_SEMAS_SIGNAL = 8
    integer(c_int), parameter :: CU_GRAPH_NODE_TYPE_EXT_SEMAS_WAIT = 9
    integer(c_int), parameter :: CU_GRAPH_NODE_TYPE_MEM_ALLOC = 10
    integer(c_int), parameter :: CU_GRAPH_NODE_TYPE_MEM_FREE = 11
    integer(c_int), parameter :: CU_GRAPH_NODE_TYPE_BATCH_MEM_OP = 12
    integer(c_int), parameter :: CU_GRAPH_NODE_TYPE_CONDITIONAL = 13

    ! ---- CUgraphDependencyType
    integer(c_int), parameter :: CU_GRAPH_DEPENDENCY_TYPE_DEFAULT = 0
    integer(c_int), parameter :: CU_GRAPH_DEPENDENCY_TYPE_PROGRAMMATIC = 1

    ! ---- CUgraphInstantiateResult
    integer(c_int), parameter :: CUDA_GRAPH_INSTANTIATE_SUCCESS = 0
    integer(c_int), parameter :: CUDA_GRAPH_INSTANTIATE_ERROR = 1
    integer(c_int), parameter :: CUDA_GRAPH_INSTANTIATE_INVALID_STRUCTURE = 2
    integer(c_int), parameter :: CUDA_GRAPH_INSTANTIATE_NODE_OPERATION_NOT_SUPPORTED = 3
    integer(c_int), parameter :: CUDA_GRAPH_INSTANTIATE_MULTIPLE_CTXS_NOT_SUPPORTED = 4
    integer(c_int), parameter :: CUDA_GRAPH_INSTANTIATE_CONDITIONAL_HANDLE_UNUSED = 5

    ! ---- CUsynchronizationPolicy
    integer(c_int), parameter :: CU_SYNC_POLICY_AUTO = 1
    integer(c_int), parameter :: CU_SYNC_POLICY_SPIN = 2
    integer(c_int), parameter :: CU_SYNC_POLICY_YIELD = 3
    integer(c_int), parameter :: CU_SYNC_POLICY_BLOCKING_SYNC = 4

    ! ---- CUclusterSchedulingPolicy
    integer(c_int), parameter :: CU_CLUSTER_SCHEDULING_POLICY_DEFAULT = 0
    integer(c_int), parameter :: CU_CLUSTER_SCHEDULING_POLICY_SPREAD = 1
    integer(c_int), parameter :: CU_CLUSTER_SCHEDULING_POLICY_LOAD_BALANCING = 2

    ! ---- CUlaunchMemSyncDomain
    integer(c_int), parameter :: CU_LAUNCH_MEM_SYNC_DOMAIN_DEFAULT = 0
    integer(c_int), parameter :: CU_LAUNCH_MEM_SYNC_DOMAIN_REMOTE = 1

    ! ---- CUlaunchAttributeID
    integer(c_int), parameter :: CU_LAUNCH_ATTRIBUTE_IGNORE = 0
    integer(c_int), parameter :: CU_LAUNCH_ATTRIBUTE_ACCESS_POLICY_WINDOW = 1
    integer(c_int), parameter :: CU_LAUNCH_ATTRIBUTE_COOPERATIVE = 2
    integer(c_int), parameter :: CU_LAUNCH_ATTRIBUTE_SYNCHRONIZATION_POLICY = 3
    integer(c_int), parameter :: CU_LAUNCH_ATTRIBUTE_CLUSTER_DIMENSION = 4
    integer(c_int), parameter :: CU_LAUNCH_ATTRIBUTE_CLUSTER_SCHEDULING_POLICY_PREFERENCE = 5
    integer(c_int), parameter :: CU_LAUNCH_ATTRIBUTE_PROGRAMMATIC_STREAM_SERIALIZATION = 6
    integer(c_int), parameter :: CU_LAUNCH_ATTRIBUTE_PROGRAMMATIC_EVENT = 7
    integer(c_int), parameter :: CU_LAUNCH_ATTRIBUTE_PRIORITY = 8
    integer(c_int), parameter :: CU_LAUNCH_ATTRIBUTE_MEM_SYNC_DOMAIN_MAP = 9
    integer(c_int), parameter :: CU_LAUNCH_ATTRIBUTE_MEM_SYNC_DOMAIN = 10
    integer(c_int), parameter :: CU_LAUNCH_ATTRIBUTE_PREFERRED_CLUSTER_DIMENSION = 11
    integer(c_int), parameter :: CU_LAUNCH_ATTRIBUTE_LAUNCH_COMPLETION_EVENT = 12
    integer(c_int), parameter :: CU_LAUNCH_ATTRIBUTE_DEVICE_UPDATABLE_KERNEL_NODE = 13
    integer(c_int), parameter :: CU_LAUNCH_ATTRIBUTE_PREFERRED_SHARED_MEMORY_CARVEOUT = 14

    ! ---- CUstreamCaptureStatus
    integer(c_int), parameter :: CU_STREAM_CAPTURE_STATUS_NONE = 0
    integer(c_int), parameter :: CU_STREAM_CAPTURE_STATUS_ACTIVE = 1
    integer(c_int), parameter :: CU_STREAM_CAPTURE_STATUS_INVALIDATED = 2

    ! ---- CUstreamCaptureMode
    integer(c_int), parameter :: CU_STREAM_CAPTURE_MODE_GLOBAL = 0
    integer(c_int), parameter :: CU_STREAM_CAPTURE_MODE_THREAD_LOCAL = 1
    integer(c_int), parameter :: CU_STREAM_CAPTURE_MODE_RELAXED = 2

    ! ---- CUdriverProcAddress_flags
    integer(c_int), parameter :: CU_GET_PROC_ADDRESS_DEFAULT = 0
    integer(c_int), parameter :: CU_GET_PROC_ADDRESS_LEGACY_STREAM = 1
    integer(c_int), parameter :: CU_GET_PROC_ADDRESS_PER_THREAD_DEFAULT_STREAM = 2

    ! ---- CUdriverProcAddressQueryResult
    integer(c_int), parameter :: CU_GET_PROC_ADDRESS_SUCCESS = 0
    integer(c_int), parameter :: CU_GET_PROC_ADDRESS_SYMBOL_NOT_FOUND = 1
    integer(c_int), parameter :: CU_GET_PROC_ADDRESS_VERSION_NOT_SUFFICIENT = 2

    ! ---- CUexecAffinityType
    integer(c_int), parameter :: CU_EXEC_AFFINITY_TYPE_SM_COUNT = 0
    integer(c_int), parameter :: CU_EXEC_AFFINITY_TYPE_MAX = 1

    ! ---- CUcigDataType
    integer(c_int), parameter :: CIG_DATA_TYPE_D3D12_COMMAND_QUEUE = 1
    integer(c_int), parameter :: CIG_DATA_TYPE_NV_BLOB = 2

    ! ---- CUlibraryOption
    integer(c_int), parameter :: CU_LIBRARY_HOST_UNIVERSAL_FUNCTION_AND_DATA_TABLE = 0
    integer(c_int), parameter :: CU_LIBRARY_BINARY_IS_PRESERVED = 1
    integer(c_int), parameter :: CU_LIBRARY_NUM_OPTIONS = 2

    ! ---- CUresult
    integer(c_int), parameter :: CUDA_SUCCESS = 0
    integer(c_int), parameter :: CUDA_ERROR_INVALID_VALUE = 1
    integer(c_int), parameter :: CUDA_ERROR_OUT_OF_MEMORY = 2
    integer(c_int), parameter :: CUDA_ERROR_NOT_INITIALIZED = 3
    integer(c_int), parameter :: CUDA_ERROR_DEINITIALIZED = 4
    integer(c_int), parameter :: CUDA_ERROR_PROFILER_DISABLED = 5
    integer(c_int), parameter :: CUDA_ERROR_PROFILER_NOT_INITIALIZED = 6
    integer(c_int), parameter :: CUDA_ERROR_PROFILER_ALREADY_STARTED = 7
    integer(c_int), parameter :: CUDA_ERROR_PROFILER_ALREADY_STOPPED = 8
    integer(c_int), parameter :: CUDA_ERROR_STUB_LIBRARY = 34
    integer(c_int), parameter :: CUDA_ERROR_DEVICE_UNAVAILABLE = 46
    integer(c_int), parameter :: CUDA_ERROR_NO_DEVICE = 100
    integer(c_int), parameter :: CUDA_ERROR_INVALID_DEVICE = 101
    integer(c_int), parameter :: CUDA_ERROR_DEVICE_NOT_LICENSED = 102
    integer(c_int), parameter :: CUDA_ERROR_INVALID_IMAGE = 200
    integer(c_int), parameter :: CUDA_ERROR_INVALID_CONTEXT = 201
    integer(c_int), parameter :: CUDA_ERROR_CONTEXT_ALREADY_CURRENT = 202
    integer(c_int), parameter :: CUDA_ERROR_MAP_FAILED = 205
    integer(c_int), parameter :: CUDA_ERROR_UNMAP_FAILED = 206
    integer(c_int), parameter :: CUDA_ERROR_ARRAY_IS_MAPPED = 207
    integer(c_int), parameter :: CUDA_ERROR_ALREADY_MAPPED = 208
    integer(c_int), parameter :: CUDA_ERROR_NO_BINARY_FOR_GPU = 209
    integer(c_int), parameter :: CUDA_ERROR_ALREADY_ACQUIRED = 210
    integer(c_int), parameter :: CUDA_ERROR_NOT_MAPPED = 211
    integer(c_int), parameter :: CUDA_ERROR_NOT_MAPPED_AS_ARRAY = 212
    integer(c_int), parameter :: CUDA_ERROR_NOT_MAPPED_AS_POINTER = 213
    integer(c_int), parameter :: CUDA_ERROR_ECC_UNCORRECTABLE = 214
    integer(c_int), parameter :: CUDA_ERROR_UNSUPPORTED_LIMIT = 215
    integer(c_int), parameter :: CUDA_ERROR_CONTEXT_ALREADY_IN_USE = 216
    integer(c_int), parameter :: CUDA_ERROR_PEER_ACCESS_UNSUPPORTED = 217
    integer(c_int), parameter :: CUDA_ERROR_INVALID_PTX = 218
    integer(c_int), parameter :: CUDA_ERROR_INVALID_GRAPHICS_CONTEXT = 219
    integer(c_int), parameter :: CUDA_ERROR_NVLINK_UNCORRECTABLE = 220
    integer(c_int), parameter :: CUDA_ERROR_JIT_COMPILER_NOT_FOUND = 221
    integer(c_int), parameter :: CUDA_ERROR_UNSUPPORTED_PTX_VERSION = 222
    integer(c_int), parameter :: CUDA_ERROR_JIT_COMPILATION_DISABLED = 223
    integer(c_int), parameter :: CUDA_ERROR_UNSUPPORTED_EXEC_AFFINITY = 224
    integer(c_int), parameter :: CUDA_ERROR_UNSUPPORTED_DEVSIDE_SYNC = 225
    integer(c_int), parameter :: CUDA_ERROR_CONTAINED = 226
    integer(c_int), parameter :: CUDA_ERROR_INVALID_SOURCE = 300
    integer(c_int), parameter :: CUDA_ERROR_FILE_NOT_FOUND = 301
    integer(c_int), parameter :: CUDA_ERROR_SHARED_OBJECT_SYMBOL_NOT_FOUND = 302
    integer(c_int), parameter :: CUDA_ERROR_SHARED_OBJECT_INIT_FAILED = 303
    integer(c_int), parameter :: CUDA_ERROR_OPERATING_SYSTEM = 304
    integer(c_int), parameter :: CUDA_ERROR_INVALID_HANDLE = 400
    integer(c_int), parameter :: CUDA_ERROR_ILLEGAL_STATE = 401
    integer(c_int), parameter :: CUDA_ERROR_LOSSY_QUERY = 402
    integer(c_int), parameter :: CUDA_ERROR_NOT_FOUND = 500
    integer(c_int), parameter :: CUDA_ERROR_NOT_READY = 600
    integer(c_int), parameter :: CUDA_ERROR_ILLEGAL_ADDRESS = 700
    integer(c_int), parameter :: CUDA_ERROR_LAUNCH_OUT_OF_RESOURCES = 701
    integer(c_int), parameter :: CUDA_ERROR_LAUNCH_TIMEOUT = 702
    integer(c_int), parameter :: CUDA_ERROR_LAUNCH_INCOMPATIBLE_TEXTURING = 703
    integer(c_int), parameter :: CUDA_ERROR_PEER_ACCESS_ALREADY_ENABLED = 704
    integer(c_int), parameter :: CUDA_ERROR_PEER_ACCESS_NOT_ENABLED = 705
    integer(c_int), parameter :: CUDA_ERROR_PRIMARY_CONTEXT_ACTIVE = 708
    integer(c_int), parameter :: CUDA_ERROR_CONTEXT_IS_DESTROYED = 709
    integer(c_int), parameter :: CUDA_ERROR_ASSERT = 710
    integer(c_int), parameter :: CUDA_ERROR_TOO_MANY_PEERS = 711
    integer(c_int), parameter :: CUDA_ERROR_HOST_MEMORY_ALREADY_REGISTERED = 712
    integer(c_int), parameter :: CUDA_ERROR_HOST_MEMORY_NOT_REGISTERED = 713
    integer(c_int), parameter :: CUDA_ERROR_HARDWARE_STACK_ERROR = 714
    integer(c_int), parameter :: CUDA_ERROR_ILLEGAL_INSTRUCTION = 715
    integer(c_int), parameter :: CUDA_ERROR_MISALIGNED_ADDRESS = 716
    integer(c_int), parameter :: CUDA_ERROR_INVALID_ADDRESS_SPACE = 717
    integer(c_int), parameter :: CUDA_ERROR_INVALID_PC = 718
    integer(c_int), parameter :: CUDA_ERROR_LAUNCH_FAILED = 719
    integer(c_int), parameter :: CUDA_ERROR_COOPERATIVE_LAUNCH_TOO_LARGE = 720
    integer(c_int), parameter :: CUDA_ERROR_TENSOR_MEMORY_LEAK = 721
    integer(c_int), parameter :: CUDA_ERROR_NOT_PERMITTED = 800
    integer(c_int), parameter :: CUDA_ERROR_NOT_SUPPORTED = 801
    integer(c_int), parameter :: CUDA_ERROR_SYSTEM_NOT_READY = 802
    integer(c_int), parameter :: CUDA_ERROR_SYSTEM_DRIVER_MISMATCH = 803
    integer(c_int), parameter :: CUDA_ERROR_COMPAT_NOT_SUPPORTED_ON_DEVICE = 804
    integer(c_int), parameter :: CUDA_ERROR_MPS_CONNECTION_FAILED = 805
    integer(c_int), parameter :: CUDA_ERROR_MPS_RPC_FAILURE = 806
    integer(c_int), parameter :: CUDA_ERROR_MPS_SERVER_NOT_READY = 807
    integer(c_int), parameter :: CUDA_ERROR_MPS_MAX_CLIENTS_REACHED = 808
    integer(c_int), parameter :: CUDA_ERROR_MPS_MAX_CONNECTIONS_REACHED = 809
    integer(c_int), parameter :: CUDA_ERROR_MPS_CLIENT_TERMINATED = 810
    integer(c_int), parameter :: CUDA_ERROR_CDP_NOT_SUPPORTED = 811
    integer(c_int), parameter :: CUDA_ERROR_CDP_VERSION_MISMATCH = 812
    integer(c_int), parameter :: CUDA_ERROR_STREAM_CAPTURE_UNSUPPORTED = 900
    integer(c_int), parameter :: CUDA_ERROR_STREAM_CAPTURE_INVALIDATED = 901
    integer(c_int), parameter :: CUDA_ERROR_STREAM_CAPTURE_MERGE = 902
    integer(c_int), parameter :: CUDA_ERROR_STREAM_CAPTURE_UNMATCHED = 903
    integer(c_int), parameter :: CUDA_ERROR_STREAM_CAPTURE_UNJOINED = 904
    integer(c_int), parameter :: CUDA_ERROR_STREAM_CAPTURE_ISOLATION = 905
    integer(c_int), parameter :: CUDA_ERROR_STREAM_CAPTURE_IMPLICIT = 906
    integer(c_int), parameter :: CUDA_ERROR_CAPTURED_EVENT = 907
    integer(c_int), parameter :: CUDA_ERROR_STREAM_CAPTURE_WRONG_THREAD = 908
    integer(c_int), parameter :: CUDA_ERROR_TIMEOUT = 909
    integer(c_int), parameter :: CUDA_ERROR_GRAPH_EXEC_UPDATE_FAILURE = 910
    integer(c_int), parameter :: CUDA_ERROR_EXTERNAL_DEVICE = 911
    integer(c_int), parameter :: CUDA_ERROR_INVALID_CLUSTER_SIZE = 912
    integer(c_int), parameter :: CUDA_ERROR_FUNCTION_NOT_LOADED = 913
    integer(c_int), parameter :: CUDA_ERROR_INVALID_RESOURCE_TYPE = 914
    integer(c_int), parameter :: CUDA_ERROR_INVALID_RESOURCE_CONFIGURATION = 915
    integer(c_int), parameter :: CUDA_ERROR_KEY_ROTATION = 916
    integer(c_int), parameter :: CUDA_ERROR_UNKNOWN = 999

    ! ---- CUdevice_P2PAttribute
    integer(c_int), parameter :: CU_DEVICE_P2P_ATTRIBUTE_PERFORMANCE_RANK = 1
    integer(c_int), parameter :: CU_DEVICE_P2P_ATTRIBUTE_ACCESS_SUPPORTED = 2
    integer(c_int), parameter :: CU_DEVICE_P2P_ATTRIBUTE_NATIVE_ATOMIC_SUPPORTED = 3
    integer(c_int), parameter :: CU_DEVICE_P2P_ATTRIBUTE_ACCESS_ACCESS_SUPPORTED = 4
    integer(c_int), parameter :: CU_DEVICE_P2P_ATTRIBUTE_CUDA_ARRAY_ACCESS_SUPPORTED = 4

    ! ---- CUresourceViewFormat
    integer(c_int), parameter :: CU_RES_VIEW_FORMAT_NONE = 0
    integer(c_int), parameter :: CU_RES_VIEW_FORMAT_UINT_1X8 = 1
    integer(c_int), parameter :: CU_RES_VIEW_FORMAT_UINT_2X8 = 2
    integer(c_int), parameter :: CU_RES_VIEW_FORMAT_UINT_4X8 = 3
    integer(c_int), parameter :: CU_RES_VIEW_FORMAT_SINT_1X8 = 4
    integer(c_int), parameter :: CU_RES_VIEW_FORMAT_SINT_2X8 = 5
    integer(c_int), parameter :: CU_RES_VIEW_FORMAT_SINT_4X8 = 6
    integer(c_int), parameter :: CU_RES_VIEW_FORMAT_UINT_1X16 = 7
    integer(c_int), parameter :: CU_RES_VIEW_FORMAT_UINT_2X16 = 8
    integer(c_int), parameter :: CU_RES_VIEW_FORMAT_UINT_4X16 = 9
    integer(c_int), parameter :: CU_RES_VIEW_FORMAT_SINT_1X16 = 10
    integer(c_int), parameter :: CU_RES_VIEW_FORMAT_SINT_2X16 = 11
    integer(c_int), parameter :: CU_RES_VIEW_FORMAT_SINT_4X16 = 12
    integer(c_int), parameter :: CU_RES_VIEW_FORMAT_UINT_1X32 = 13
    integer(c_int), parameter :: CU_RES_VIEW_FORMAT_UINT_2X32 = 14
    integer(c_int), parameter :: CU_RES_VIEW_FORMAT_UINT_4X32 = 15
    integer(c_int), parameter :: CU_RES_VIEW_FORMAT_SINT_1X32 = 16
    integer(c_int), parameter :: CU_RES_VIEW_FORMAT_SINT_2X32 = 17
    integer(c_int), parameter :: CU_RES_VIEW_FORMAT_SINT_4X32 = 18
    integer(c_int), parameter :: CU_RES_VIEW_FORMAT_FLOAT_1X16 = 19
    integer(c_int), parameter :: CU_RES_VIEW_FORMAT_FLOAT_2X16 = 20
    integer(c_int), parameter :: CU_RES_VIEW_FORMAT_FLOAT_4X16 = 21
    integer(c_int), parameter :: CU_RES_VIEW_FORMAT_FLOAT_1X32 = 22
    integer(c_int), parameter :: CU_RES_VIEW_FORMAT_FLOAT_2X32 = 23
    integer(c_int), parameter :: CU_RES_VIEW_FORMAT_FLOAT_4X32 = 24
    integer(c_int), parameter :: CU_RES_VIEW_FORMAT_UNSIGNED_BC1 = 25
    integer(c_int), parameter :: CU_RES_VIEW_FORMAT_UNSIGNED_BC2 = 26
    integer(c_int), parameter :: CU_RES_VIEW_FORMAT_UNSIGNED_BC3 = 27
    integer(c_int), parameter :: CU_RES_VIEW_FORMAT_UNSIGNED_BC4 = 28
    integer(c_int), parameter :: CU_RES_VIEW_FORMAT_SIGNED_BC4 = 29
    integer(c_int), parameter :: CU_RES_VIEW_FORMAT_UNSIGNED_BC5 = 30
    integer(c_int), parameter :: CU_RES_VIEW_FORMAT_SIGNED_BC5 = 31
    integer(c_int), parameter :: CU_RES_VIEW_FORMAT_UNSIGNED_BC6H = 32
    integer(c_int), parameter :: CU_RES_VIEW_FORMAT_SIGNED_BC6H = 33
    integer(c_int), parameter :: CU_RES_VIEW_FORMAT_UNSIGNED_BC7 = 34

    ! ---- CUtensorMapDataType
    integer(c_int), parameter :: CU_TENSOR_MAP_DATA_TYPE_UINT8 = 0
    integer(c_int), parameter :: CU_TENSOR_MAP_DATA_TYPE_UINT16 = 1
    integer(c_int), parameter :: CU_TENSOR_MAP_DATA_TYPE_UINT32 = 2
    integer(c_int), parameter :: CU_TENSOR_MAP_DATA_TYPE_INT32 = 3
    integer(c_int), parameter :: CU_TENSOR_MAP_DATA_TYPE_UINT64 = 4
    integer(c_int), parameter :: CU_TENSOR_MAP_DATA_TYPE_INT64 = 5
    integer(c_int), parameter :: CU_TENSOR_MAP_DATA_TYPE_FLOAT16 = 6
    integer(c_int), parameter :: CU_TENSOR_MAP_DATA_TYPE_FLOAT32 = 7
    integer(c_int), parameter :: CU_TENSOR_MAP_DATA_TYPE_FLOAT64 = 8
    integer(c_int), parameter :: CU_TENSOR_MAP_DATA_TYPE_BFLOAT16 = 9
    integer(c_int), parameter :: CU_TENSOR_MAP_DATA_TYPE_FLOAT32_FTZ = 10
    integer(c_int), parameter :: CU_TENSOR_MAP_DATA_TYPE_TFLOAT32 = 11
    integer(c_int), parameter :: CU_TENSOR_MAP_DATA_TYPE_TFLOAT32_FTZ = 12
    integer(c_int), parameter :: CU_TENSOR_MAP_DATA_TYPE_16U4_ALIGN8B = 13
    integer(c_int), parameter :: CU_TENSOR_MAP_DATA_TYPE_16U4_ALIGN16B = 14
    integer(c_int), parameter :: CU_TENSOR_MAP_DATA_TYPE_16U6_ALIGN16B = 15

    ! ---- CUtensorMapInterleave
    integer(c_int), parameter :: CU_TENSOR_MAP_INTERLEAVE_NONE = 0
    integer(c_int), parameter :: CU_TENSOR_MAP_INTERLEAVE_16B = 1
    integer(c_int), parameter :: CU_TENSOR_MAP_INTERLEAVE_32B = 2

    ! ---- CUtensorMapSwizzle
    integer(c_int), parameter :: CU_TENSOR_MAP_SWIZZLE_NONE = 0
    integer(c_int), parameter :: CU_TENSOR_MAP_SWIZZLE_32B = 1
    integer(c_int), parameter :: CU_TENSOR_MAP_SWIZZLE_64B = 2
    integer(c_int), parameter :: CU_TENSOR_MAP_SWIZZLE_128B = 3
    integer(c_int), parameter :: CU_TENSOR_MAP_SWIZZLE_128B_ATOM_32B = 4
    integer(c_int), parameter :: CU_TENSOR_MAP_SWIZZLE_128B_ATOM_32B_FLIP_8B = 5
    integer(c_int), parameter :: CU_TENSOR_MAP_SWIZZLE_128B_ATOM_64B = 6

    ! ---- CUtensorMapL2promotion
    integer(c_int), parameter :: CU_TENSOR_MAP_L2_PROMOTION_NONE = 0
    integer(c_int), parameter :: CU_TENSOR_MAP_L2_PROMOTION_L2_64B = 1
    integer(c_int), parameter :: CU_TENSOR_MAP_L2_PROMOTION_L2_128B = 2
    integer(c_int), parameter :: CU_TENSOR_MAP_L2_PROMOTION_L2_256B = 3

    ! ---- CUtensorMapFloatOOBfill
    integer(c_int), parameter :: CU_TENSOR_MAP_FLOAT_OOB_FILL_NONE = 0
    integer(c_int), parameter :: CU_TENSOR_MAP_FLOAT_OOB_FILL_NAN_REQUEST_ZERO_FMA = 1

    ! ---- CUtensorMapIm2ColWideMode
    integer(c_int), parameter :: CU_TENSOR_MAP_IM2COL_WIDE_MODE_W = 0
    integer(c_int), parameter :: CU_TENSOR_MAP_IM2COL_WIDE_MODE_W128 = 1

    ! ---- CUDA_POINTER_ATTRIBUTE_ACCESS_FLAGS
    integer(c_int), parameter :: CU_POINTER_ATTRIBUTE_ACCESS_FLAG_NONE = 0
    integer(c_int), parameter :: CU_POINTER_ATTRIBUTE_ACCESS_FLAG_READ = 1
    integer(c_int), parameter :: CU_POINTER_ATTRIBUTE_ACCESS_FLAG_READWRITE = 3

    ! ---- CUexternalMemoryHandleType
    integer(c_int), parameter :: CU_EXTERNAL_MEMORY_HANDLE_TYPE_OPAQUE_FD = 1
    integer(c_int), parameter :: CU_EXTERNAL_MEMORY_HANDLE_TYPE_OPAQUE_WIN32 = 2
    integer(c_int), parameter :: CU_EXTERNAL_MEMORY_HANDLE_TYPE_OPAQUE_WIN32_KMT = 3
    integer(c_int), parameter :: CU_EXTERNAL_MEMORY_HANDLE_TYPE_D3D12_HEAP = 4
    integer(c_int), parameter :: CU_EXTERNAL_MEMORY_HANDLE_TYPE_D3D12_RESOURCE = 5
    integer(c_int), parameter :: CU_EXTERNAL_MEMORY_HANDLE_TYPE_D3D11_RESOURCE = 6
    integer(c_int), parameter :: CU_EXTERNAL_MEMORY_HANDLE_TYPE_D3D11_RESOURCE_KMT = 7
    integer(c_int), parameter :: CU_EXTERNAL_MEMORY_HANDLE_TYPE_NVSCIBUF = 8

    ! ---- CUexternalSemaphoreHandleType
    integer(c_int), parameter :: CU_EXTERNAL_SEMAPHORE_HANDLE_TYPE_OPAQUE_FD = 1
    integer(c_int), parameter :: CU_EXTERNAL_SEMAPHORE_HANDLE_TYPE_OPAQUE_WIN32 = 2
    integer(c_int), parameter :: CU_EXTERNAL_SEMAPHORE_HANDLE_TYPE_OPAQUE_WIN32_KMT = 3
    integer(c_int), parameter :: CU_EXTERNAL_SEMAPHORE_HANDLE_TYPE_D3D12_FENCE = 4
    integer(c_int), parameter :: CU_EXTERNAL_SEMAPHORE_HANDLE_TYPE_D3D11_FENCE = 5
    integer(c_int), parameter :: CU_EXTERNAL_SEMAPHORE_HANDLE_TYPE_NVSCISYNC = 6
    integer(c_int), parameter :: CU_EXTERNAL_SEMAPHORE_HANDLE_TYPE_D3D11_KEYED_MUTEX = 7
    integer(c_int), parameter :: CU_EXTERNAL_SEMAPHORE_HANDLE_TYPE_D3D11_KEYED_MUTEX_KMT = 8
    integer(c_int), parameter :: CU_EXTERNAL_SEMAPHORE_HANDLE_TYPE_TIMELINE_SEMAPHORE_FD = 9
    integer(c_int), parameter :: CU_EXTERNAL_SEMAPHORE_HANDLE_TYPE_TIMELINE_SEMAPHORE_WIN32 = 10

    ! ---- CUmemAllocationHandleType
    integer(c_int), parameter :: CU_MEM_HANDLE_TYPE_NONE = 0
    integer(c_int), parameter :: CU_MEM_HANDLE_TYPE_POSIX_FILE_DESCRIPTOR = 1
    integer(c_int), parameter :: CU_MEM_HANDLE_TYPE_WIN32 = 2
    integer(c_int), parameter :: CU_MEM_HANDLE_TYPE_WIN32_KMT = 4
    integer(c_int), parameter :: CU_MEM_HANDLE_TYPE_FABRIC = 8
    integer(c_int), parameter :: CU_MEM_HANDLE_TYPE_MAX = 2147483647

    ! ---- CUmemAccess_flags
    integer(c_int), parameter :: CU_MEM_ACCESS_FLAGS_PROT_NONE = 0
    integer(c_int), parameter :: CU_MEM_ACCESS_FLAGS_PROT_READ = 1
    integer(c_int), parameter :: CU_MEM_ACCESS_FLAGS_PROT_READWRITE = 3
    integer(c_int), parameter :: CU_MEM_ACCESS_FLAGS_PROT_MAX = 2147483647

    ! ---- CUmemLocationType
    integer(c_int), parameter :: CU_MEM_LOCATION_TYPE_INVALID = 0
    integer(c_int), parameter :: CU_MEM_LOCATION_TYPE_DEVICE = 1
    integer(c_int), parameter :: CU_MEM_LOCATION_TYPE_HOST = 2
    integer(c_int), parameter :: CU_MEM_LOCATION_TYPE_HOST_NUMA = 3
    integer(c_int), parameter :: CU_MEM_LOCATION_TYPE_HOST_NUMA_CURRENT = 4
    integer(c_int), parameter :: CU_MEM_LOCATION_TYPE_MAX = 2147483647

    ! ---- CUmemAllocationType
    integer(c_int), parameter :: CU_MEM_ALLOCATION_TYPE_INVALID = 0
    integer(c_int), parameter :: CU_MEM_ALLOCATION_TYPE_PINNED = 1
    integer(c_int), parameter :: CU_MEM_ALLOCATION_TYPE_MAX = 2147483647

    ! ---- CUmemAllocationGranularity_flags
    integer(c_int), parameter :: CU_MEM_ALLOC_GRANULARITY_MINIMUM = 0
    integer(c_int), parameter :: CU_MEM_ALLOC_GRANULARITY_RECOMMENDED = 1

    ! ---- CUmemRangeHandleType
    integer(c_int), parameter :: CU_MEM_RANGE_HANDLE_TYPE_DMA_BUF_FD = 1
    integer(c_int), parameter :: CU_MEM_RANGE_HANDLE_TYPE_MAX = 2147483647

    ! ---- CUmemRangeFlags
    integer(c_int), parameter :: CU_MEM_RANGE_FLAG_DMA_BUF_MAPPING_TYPE_PCIE = 1

    ! ---- CUarraySparseSubresourceType
    integer(c_int), parameter :: CU_ARRAY_SPARSE_SUBRESOURCE_TYPE_SPARSE_LEVEL = 0
    integer(c_int), parameter :: CU_ARRAY_SPARSE_SUBRESOURCE_TYPE_MIPTAIL = 1

    ! ---- CUmemOperationType
    integer(c_int), parameter :: CU_MEM_OPERATION_TYPE_MAP = 1
    integer(c_int), parameter :: CU_MEM_OPERATION_TYPE_UNMAP = 2

    ! ---- CUmemHandleType
    integer(c_int), parameter :: CU_MEM_HANDLE_TYPE_GENERIC = 0

    ! ---- CUmemAllocationCompType
    integer(c_int), parameter :: CU_MEM_ALLOCATION_COMP_NONE = 0
    integer(c_int), parameter :: CU_MEM_ALLOCATION_COMP_GENERIC = 1

    ! ---- CUmulticastGranularity_flags
    integer(c_int), parameter :: CU_MULTICAST_GRANULARITY_MINIMUM = 0
    integer(c_int), parameter :: CU_MULTICAST_GRANULARITY_RECOMMENDED = 1

    ! ---- CUgraphExecUpdateResult
    integer(c_int), parameter :: CU_GRAPH_EXEC_UPDATE_SUCCESS = 0
    integer(c_int), parameter :: CU_GRAPH_EXEC_UPDATE_ERROR = 1
    integer(c_int), parameter :: CU_GRAPH_EXEC_UPDATE_ERROR_TOPOLOGY_CHANGED = 2
    integer(c_int), parameter :: CU_GRAPH_EXEC_UPDATE_ERROR_NODE_TYPE_CHANGED = 3
    integer(c_int), parameter :: CU_GRAPH_EXEC_UPDATE_ERROR_FUNCTION_CHANGED = 4
    integer(c_int), parameter :: CU_GRAPH_EXEC_UPDATE_ERROR_PARAMETERS_CHANGED = 5
    integer(c_int), parameter :: CU_GRAPH_EXEC_UPDATE_ERROR_NOT_SUPPORTED = 6
    integer(c_int), parameter :: CU_GRAPH_EXEC_UPDATE_ERROR_UNSUPPORTED_FUNCTION_CHANGE = 7
    integer(c_int), parameter :: CU_GRAPH_EXEC_UPDATE_ERROR_ATTRIBUTES_CHANGED = 8

    ! ---- CUmemPool_attribute
    integer(c_int), parameter :: CU_MEMPOOL_ATTR_REUSE_FOLLOW_EVENT_DEPENDENCIES = 1
    integer(c_int), parameter :: CU_MEMPOOL_ATTR_REUSE_ALLOW_OPPORTUNISTIC = 2
    integer(c_int), parameter :: CU_MEMPOOL_ATTR_REUSE_ALLOW_INTERNAL_DEPENDENCIES = 3
    integer(c_int), parameter :: CU_MEMPOOL_ATTR_RELEASE_THRESHOLD = 4
    integer(c_int), parameter :: CU_MEMPOOL_ATTR_RESERVED_MEM_CURRENT = 5
    integer(c_int), parameter :: CU_MEMPOOL_ATTR_RESERVED_MEM_HIGH = 6
    integer(c_int), parameter :: CU_MEMPOOL_ATTR_USED_MEM_CURRENT = 7
    integer(c_int), parameter :: CU_MEMPOOL_ATTR_USED_MEM_HIGH = 8

    ! ---- CUmemcpyFlags
    integer(c_int), parameter :: CU_MEMCPY_FLAG_DEFAULT = 0
    integer(c_int), parameter :: CU_MEMCPY_FLAG_PREFER_OVERLAP_WITH_COMPUTE = 1

    ! ---- CUmemcpySrcAccessOrder
    integer(c_int), parameter :: CU_MEMCPY_SRC_ACCESS_ORDER_INVALID = 0
    integer(c_int), parameter :: CU_MEMCPY_SRC_ACCESS_ORDER_STREAM = 1
    integer(c_int), parameter :: CU_MEMCPY_SRC_ACCESS_ORDER_DURING_API_CALL = 2
    integer(c_int), parameter :: CU_MEMCPY_SRC_ACCESS_ORDER_ANY = 3
    integer(c_int), parameter :: CU_MEMCPY_SRC_ACCESS_ORDER_MAX = 2147483647

    ! ---- CUmemcpy3DOperandType
    integer(c_int), parameter :: CU_MEMCPY_OPERAND_TYPE_POINTER = 1
    integer(c_int), parameter :: CU_MEMCPY_OPERAND_TYPE_ARRAY = 2
    integer(c_int), parameter :: CU_MEMCPY_OPERAND_TYPE_MAX = 2147483647

    ! ---- CUgraphMem_attribute
    integer(c_int), parameter :: CU_GRAPH_MEM_ATTR_USED_MEM_CURRENT = 0
    integer(c_int), parameter :: CU_GRAPH_MEM_ATTR_USED_MEM_HIGH = 1
    integer(c_int), parameter :: CU_GRAPH_MEM_ATTR_RESERVED_MEM_CURRENT = 2
    integer(c_int), parameter :: CU_GRAPH_MEM_ATTR_RESERVED_MEM_HIGH = 3

    ! ---- CUgraphChildGraphNodeOwnership
    integer(c_int), parameter :: CU_GRAPH_CHILD_GRAPH_OWNERSHIP_CLONE = 0
    integer(c_int), parameter :: CU_GRAPH_CHILD_GRAPH_OWNERSHIP_MOVE = 1

    ! ---- CUflushGPUDirectRDMAWritesOptions
    integer(c_int), parameter :: CU_FLUSH_GPU_DIRECT_RDMA_WRITES_OPTION_HOST = 1
    integer(c_int), parameter :: CU_FLUSH_GPU_DIRECT_RDMA_WRITES_OPTION_MEMOPS = 2

    ! ---- CUGPUDirectRDMAWritesOrdering
    integer(c_int), parameter :: CU_GPU_DIRECT_RDMA_WRITES_ORDERING_NONE = 0
    integer(c_int), parameter :: CU_GPU_DIRECT_RDMA_WRITES_ORDERING_OWNER = 100
    integer(c_int), parameter :: CU_GPU_DIRECT_RDMA_WRITES_ORDERING_ALL_DEVICES = 200

    ! ---- CUflushGPUDirectRDMAWritesScope
    integer(c_int), parameter :: CU_FLUSH_GPU_DIRECT_RDMA_WRITES_TO_OWNER = 100
    integer(c_int), parameter :: CU_FLUSH_GPU_DIRECT_RDMA_WRITES_TO_ALL_DEVICES = 200

    ! ---- CUflushGPUDirectRDMAWritesTarget
    integer(c_int), parameter :: CU_FLUSH_GPU_DIRECT_RDMA_WRITES_TARGET_CURRENT_CTX = 0

    ! ---- CUgraphDebugDot_flags
    integer(c_int), parameter :: CU_GRAPH_DEBUG_DOT_FLAGS_VERBOSE = 1
    integer(c_int), parameter :: CU_GRAPH_DEBUG_DOT_FLAGS_RUNTIME_TYPES = 2
    integer(c_int), parameter :: CU_GRAPH_DEBUG_DOT_FLAGS_KERNEL_NODE_PARAMS = 4
    integer(c_int), parameter :: CU_GRAPH_DEBUG_DOT_FLAGS_MEMCPY_NODE_PARAMS = 8
    integer(c_int), parameter :: CU_GRAPH_DEBUG_DOT_FLAGS_MEMSET_NODE_PARAMS = 16
    integer(c_int), parameter :: CU_GRAPH_DEBUG_DOT_FLAGS_HOST_NODE_PARAMS = 32
    integer(c_int), parameter :: CU_GRAPH_DEBUG_DOT_FLAGS_EVENT_NODE_PARAMS = 64
    integer(c_int), parameter :: CU_GRAPH_DEBUG_DOT_FLAGS_EXT_SEMAS_SIGNAL_NODE_PARAMS = 128
    integer(c_int), parameter :: CU_GRAPH_DEBUG_DOT_FLAGS_EXT_SEMAS_WAIT_NODE_PARAMS = 256
    integer(c_int), parameter :: CU_GRAPH_DEBUG_DOT_FLAGS_KERNEL_NODE_ATTRIBUTES = 512
    integer(c_int), parameter :: CU_GRAPH_DEBUG_DOT_FLAGS_HANDLES = 1024
    integer(c_int), parameter :: CU_GRAPH_DEBUG_DOT_FLAGS_MEM_ALLOC_NODE_PARAMS = 2048
    integer(c_int), parameter :: CU_GRAPH_DEBUG_DOT_FLAGS_MEM_FREE_NODE_PARAMS = 4096
    integer(c_int), parameter :: CU_GRAPH_DEBUG_DOT_FLAGS_BATCH_MEM_OP_NODE_PARAMS = 8192
    integer(c_int), parameter :: CU_GRAPH_DEBUG_DOT_FLAGS_EXTRA_TOPO_INFO = 16384
    integer(c_int), parameter :: CU_GRAPH_DEBUG_DOT_FLAGS_CONDITIONAL_NODE_PARAMS = 32768

    ! ---- CUuserObject_flags
    integer(c_int), parameter :: CU_USER_OBJECT_NO_DESTRUCTOR_SYNC = 1

    ! ---- CUuserObjectRetain_flags
    integer(c_int), parameter :: CU_GRAPH_USER_OBJECT_MOVE = 1

    ! ---- CUgraphInstantiate_flags
    integer(c_int), parameter :: CUDA_GRAPH_INSTANTIATE_FLAG_AUTO_FREE_ON_LAUNCH = 1
    integer(c_int), parameter :: CUDA_GRAPH_INSTANTIATE_FLAG_UPLOAD = 2
    integer(c_int), parameter :: CUDA_GRAPH_INSTANTIATE_FLAG_DEVICE_LAUNCH = 4
    integer(c_int), parameter :: CUDA_GRAPH_INSTANTIATE_FLAG_USE_NODE_PRIORITY = 8

    ! ---- CUdeviceNumaConfig
    integer(c_int), parameter :: CU_DEVICE_NUMA_CONFIG_NONE = 0
    integer(c_int), parameter :: CU_DEVICE_NUMA_CONFIG_NUMA_NODE = 1

    ! ---- CUprocessState
    integer(c_int), parameter :: CU_PROCESS_STATE_RUNNING = 0
    integer(c_int), parameter :: CU_PROCESS_STATE_LOCKED = 1
    integer(c_int), parameter :: CU_PROCESS_STATE_CHECKPOINTED = 2
    integer(c_int), parameter :: CU_PROCESS_STATE_FAILED = 3

    ! ---- CUmoduleLoadingMode
    integer(c_int), parameter :: CU_MODULE_EAGER_LOADING = 1
    integer(c_int), parameter :: CU_MODULE_LAZY_LOADING = 2

    ! ---- CUmemDecompressAlgorithm
    integer(c_int), parameter :: CU_MEM_DECOMPRESS_UNSUPPORTED = 0
    integer(c_int), parameter :: CU_MEM_DECOMPRESS_ALGORITHM_DEFLATE = 1
    integer(c_int), parameter :: CU_MEM_DECOMPRESS_ALGORITHM_SNAPPY = 2
    integer(c_int), parameter :: CU_MEM_DECOMPRESS_ALGORITHM_LZ4 = 4

    ! ---- CUfunctionLoadingState
    integer(c_int), parameter :: CU_FUNCTION_LOADING_STATE_UNLOADED = 0
    integer(c_int), parameter :: CU_FUNCTION_LOADING_STATE_LOADED = 1
    integer(c_int), parameter :: CU_FUNCTION_LOADING_STATE_MAX = 2

    ! ---- CUcoredumpSettings
    integer(c_int), parameter :: CU_COREDUMP_ENABLE_ON_EXCEPTION = 1
    integer(c_int), parameter :: CU_COREDUMP_TRIGGER_HOST = 2
    integer(c_int), parameter :: CU_COREDUMP_LIGHTWEIGHT = 3
    integer(c_int), parameter :: CU_COREDUMP_ENABLE_USER_TRIGGER = 4
    integer(c_int), parameter :: CU_COREDUMP_FILE = 5
    integer(c_int), parameter :: CU_COREDUMP_PIPE = 6
    integer(c_int), parameter :: CU_COREDUMP_GENERATION_FLAGS = 7
    integer(c_int), parameter :: CU_COREDUMP_MAX = 8

    ! ---- CUCoredumpGenerationFlags
    integer(c_int), parameter :: CU_COREDUMP_DEFAULT_FLAGS = 0
    integer(c_int), parameter :: CU_COREDUMP_SKIP_NONRELOCATED_ELF_IMAGES = 1
    integer(c_int), parameter :: CU_COREDUMP_SKIP_GLOBAL_MEMORY = 2
    integer(c_int), parameter :: CU_COREDUMP_SKIP_SHARED_MEMORY = 4
    integer(c_int), parameter :: CU_COREDUMP_SKIP_LOCAL_MEMORY = 8
    integer(c_int), parameter :: CU_COREDUMP_SKIP_ABORT = 16
    integer(c_int), parameter :: CU_COREDUMP_SKIP_CONSTBANK_MEMORY = 32

    ! ---- CUgreenCtxCreate_flags
    integer(c_int), parameter :: CU_GREEN_CTX_DEFAULT_STREAM = 1

    ! ---- CUdevSmResourceSplit_flags
    integer(c_int), parameter :: CU_DEV_SM_RESOURCE_SPLIT_IGNORE_SM_COSCHEDULING = 1
    integer(c_int), parameter :: CU_DEV_SM_RESOURCE_SPLIT_MAX_POTENTIAL_CLUSTER_SIZE = 2

    ! ---- CUdevResourceType
    integer(c_int), parameter :: CU_DEV_RESOURCE_TYPE_INVALID = 0
    integer(c_int), parameter :: CU_DEV_RESOURCE_TYPE_SM = 1

    ! ---- CUlogLevel
    integer(c_int), parameter :: CU_LOG_LEVEL_ERROR = 0
    integer(c_int), parameter :: CU_LOG_LEVEL_WARNING = 1

    ! ======================================================================
    !  Flag constants defined as C macros rather than enumerators
    !  (stream/event/host-alloc/device-schedule flags, ...)
    ! ======================================================================
    integer(c_int), parameter :: CUDA_ARRAY3D_2DARRAY = 1
    integer(c_int), parameter :: CUDA_ARRAY3D_COLOR_ATTACHMENT = 32
    integer(c_int), parameter :: CUDA_ARRAY3D_CUBEMAP = 4
    integer(c_int), parameter :: CUDA_ARRAY3D_DEFERRED_MAPPING = 128
    integer(c_int), parameter :: CUDA_ARRAY3D_DEPTH_TEXTURE = 16
    integer(c_int), parameter :: CUDA_ARRAY3D_LAYERED = 1
    integer(c_int), parameter :: CUDA_ARRAY3D_SPARSE = 64
    integer(c_int), parameter :: CUDA_ARRAY3D_SURFACE_LDST = 2
    integer(c_int), parameter :: CUDA_ARRAY3D_TEXTURE_GATHER = 8
    integer(c_int), parameter :: CUDA_ARRAY3D_VIDEO_ENCODE_DECODE = 256
    integer(c_int), parameter :: CUDA_COOPERATIVE_LAUNCH_MULTI_DEVICE_NO_POST_LAUNCH_SYNC = 2
    integer(c_int), parameter :: CUDA_COOPERATIVE_LAUNCH_MULTI_DEVICE_NO_PRE_LAUNCH_SYNC = 1
    integer(c_int), parameter :: CUDA_EXTERNAL_MEMORY_DEDICATED = 1
    integer(c_int), parameter :: CUDA_EXTERNAL_SEMAPHORE_SIGNAL_SKIP_NVSCIBUF_MEMSYNC = 1
    integer(c_int), parameter :: CUDA_EXTERNAL_SEMAPHORE_WAIT_SKIP_NVSCIBUF_MEMSYNC = 2
    integer(c_int), parameter :: CUDA_NVSCISYNC_ATTR_SIGNAL = 1
    integer(c_int), parameter :: CUDA_NVSCISYNC_ATTR_WAIT = 2
    integer(c_int), parameter :: CUDA_VERSION = 12090
    integer(c_int), parameter :: CU_ARRAY_SPARSE_PROPERTIES_SINGLE_MIPTAIL = 1
    integer(c_int), parameter :: CU_COMPUTE_ACCELERATED_TARGET_BASE = 65536
    integer(c_int), parameter :: CU_COMPUTE_FAMILY_TARGET_BASE = 131072
    integer(c_int), parameter :: CU_GRAPH_COND_ASSIGN_DEFAULT = 1
    integer(c_int), parameter :: CU_GRAPH_KERNEL_NODE_PORT_DEFAULT = 0
    integer(c_int), parameter :: CU_GRAPH_KERNEL_NODE_PORT_LAUNCH_ORDER = 2
    integer(c_int), parameter :: CU_GRAPH_KERNEL_NODE_PORT_PROGRAMMATIC = 1
    integer(c_int), parameter :: CU_IPC_HANDLE_SIZE = 64
    integer(c_int), parameter :: CU_LAUNCH_KERNEL_REQUIRED_BLOCK_DIM = 1
    integer(c_int), parameter :: CU_LAUNCH_PARAM_BUFFER_POINTER_AS_INT = 1
    integer(c_int), parameter :: CU_LAUNCH_PARAM_BUFFER_SIZE_AS_INT = 2
    integer(c_int), parameter :: CU_LAUNCH_PARAM_END_AS_INT = 0
    integer(c_int), parameter :: CU_MEMHOSTALLOC_DEVICEMAP = 2
    integer(c_int), parameter :: CU_MEMHOSTALLOC_PORTABLE = 1
    integer(c_int), parameter :: CU_MEMHOSTALLOC_WRITECOMBINED = 4
    integer(c_int), parameter :: CU_MEMHOSTREGISTER_DEVICEMAP = 2
    integer(c_int), parameter :: CU_MEMHOSTREGISTER_IOMEMORY = 4
    integer(c_int), parameter :: CU_MEMHOSTREGISTER_PORTABLE = 1
    integer(c_int), parameter :: CU_MEMHOSTREGISTER_READ_ONLY = 8
    integer(c_int), parameter :: CU_MEM_CREATE_USAGE_HW_DECOMPRESS = 2
    integer(c_int), parameter :: CU_MEM_CREATE_USAGE_TILE_POOL = 1
    integer(c_int), parameter :: CU_MEM_POOL_CREATE_USAGE_HW_DECOMPRESS = 2
    integer(c_int), parameter :: CU_PARAM_TR_DEFAULT = -1
    integer(c_int), parameter :: CU_TENSOR_MAP_NUM_QWORDS = 16
    integer(c_int), parameter :: CU_TRSA_OVERRIDE_FORMAT = 1
    integer(c_int), parameter :: CU_TRSF_DISABLE_TRILINEAR_OPTIMIZATION = 32
    integer(c_int), parameter :: CU_TRSF_NORMALIZED_COORDINATES = 2
    integer(c_int), parameter :: CU_TRSF_READ_AS_INTEGER = 1
    integer(c_int), parameter :: CU_TRSF_SEAMLESS_CUBEMAP = 64
    integer(c_int), parameter :: CU_TRSF_SRGB = 16

    ! ======================================================================
    !  Interoperable derived types
    ! ======================================================================
    ! CUstreamBatchMemOpParams_union is a C union: no Fortran equivalent, so it is
    ! declared as an opaque 48-byte buffer (size measured by the C probe).
    type, bind(C) :: CUstreamBatchMemOpParams_union
        integer(c_int64_t) :: raw(6)
    end type CUstreamBatchMemOpParams_union

    ! CUlaunchAttributeValue_union is a C union: no Fortran equivalent, so it is
    ! declared as an opaque 64-byte buffer (size measured by the C probe).
    type, bind(C) :: CUlaunchAttributeValue_union
        integer(c_int64_t) :: raw(8)
    end type CUlaunchAttributeValue_union

    type, bind(C) :: CUuuid_st
        character(kind=c_char) :: bytes(16)
    end type CUuuid_st

    type, bind(C) :: CUmemFabricHandle_st
        integer(c_signed_char) :: data(64)
    end type CUmemFabricHandle_st

    type, bind(C) :: CUipcEventHandle_st
        character(kind=c_char) :: reserved(64)
    end type CUipcEventHandle_st

    type, bind(C) :: CUipcMemHandle_st
        character(kind=c_char) :: reserved(64)
    end type CUipcMemHandle_st

    type, bind(C) :: CUDA_BATCH_MEM_OP_NODE_PARAMS_v1_st
        type(c_ptr) :: ctx
        integer(c_int) :: count
        type(c_ptr) :: paramArray
        integer(c_int) :: flags
    end type CUDA_BATCH_MEM_OP_NODE_PARAMS_v1_st

    type, bind(C) :: CUDA_BATCH_MEM_OP_NODE_PARAMS_v2_st
        type(c_ptr) :: ctx
        integer(c_int) :: count
        type(c_ptr) :: paramArray
        integer(c_int) :: flags
    end type CUDA_BATCH_MEM_OP_NODE_PARAMS_v2_st

    type, bind(C) :: CUasyncNotificationInfo_st
        integer(c_int) :: type
        integer(c_int64_t) :: info(1)   ! C union / anonymous struct
    end type CUasyncNotificationInfo_st

    type, bind(C) :: CUdevprop_st
        integer(c_int) :: maxThreadsPerBlock
        integer(c_int) :: maxThreadsDim(3)
        integer(c_int) :: maxGridSize(3)
        integer(c_int) :: sharedMemPerBlock
        integer(c_int) :: totalConstantMemory
        integer(c_int) :: SIMDWidth
        integer(c_int) :: memPitch
        integer(c_int) :: regsPerBlock
        integer(c_int) :: clockRate
        integer(c_int) :: textureAlign
    end type CUdevprop_st

    type, bind(C) :: CUaccessPolicyWindow_st
        type(c_ptr) :: base_ptr
        integer(c_size_t) :: num_bytes
        real(c_float) :: hitRatio
        integer(c_int) :: hitProp
        integer(c_int) :: missProp
    end type CUaccessPolicyWindow_st

    type, bind(C) :: CUDA_KERNEL_NODE_PARAMS_st
        type(c_ptr) :: func
        integer(c_int) :: gridDimX
        integer(c_int) :: gridDimY
        integer(c_int) :: gridDimZ
        integer(c_int) :: blockDimX
        integer(c_int) :: blockDimY
        integer(c_int) :: blockDimZ
        integer(c_int) :: sharedMemBytes
        type(c_ptr) :: kernelParams
        type(c_ptr) :: extra
    end type CUDA_KERNEL_NODE_PARAMS_st

    type, bind(C) :: CUDA_KERNEL_NODE_PARAMS_v2_st
        type(c_ptr) :: func
        integer(c_int) :: gridDimX
        integer(c_int) :: gridDimY
        integer(c_int) :: gridDimZ
        integer(c_int) :: blockDimX
        integer(c_int) :: blockDimY
        integer(c_int) :: blockDimZ
        integer(c_int) :: sharedMemBytes
        type(c_ptr) :: kernelParams
        type(c_ptr) :: extra
        type(c_ptr) :: kern
        type(c_ptr) :: ctx
    end type CUDA_KERNEL_NODE_PARAMS_v2_st

    type, bind(C) :: CUDA_KERNEL_NODE_PARAMS_v3_st
        type(c_ptr) :: func
        integer(c_int) :: gridDimX
        integer(c_int) :: gridDimY
        integer(c_int) :: gridDimZ
        integer(c_int) :: blockDimX
        integer(c_int) :: blockDimY
        integer(c_int) :: blockDimZ
        integer(c_int) :: sharedMemBytes
        type(c_ptr) :: kernelParams
        type(c_ptr) :: extra
        type(c_ptr) :: kern
        type(c_ptr) :: ctx
    end type CUDA_KERNEL_NODE_PARAMS_v3_st

    type, bind(C) :: CUDA_MEMSET_NODE_PARAMS_st
        integer(c_long_long) :: dst
        integer(c_size_t) :: pitch
        integer(c_int) :: value
        integer(c_int) :: elementSize
        integer(c_size_t) :: width
        integer(c_size_t) :: height
    end type CUDA_MEMSET_NODE_PARAMS_st

    type, bind(C) :: CUDA_MEMSET_NODE_PARAMS_v2_st
        integer(c_long_long) :: dst
        integer(c_size_t) :: pitch
        integer(c_int) :: value
        integer(c_int) :: elementSize
        integer(c_size_t) :: width
        integer(c_size_t) :: height
        type(c_ptr) :: ctx
    end type CUDA_MEMSET_NODE_PARAMS_v2_st

    type, bind(C) :: CUDA_HOST_NODE_PARAMS_st
        type(c_ptr) :: fn
        type(c_ptr) :: userData
    end type CUDA_HOST_NODE_PARAMS_st

    type, bind(C) :: CUDA_HOST_NODE_PARAMS_v2_st
        type(c_ptr) :: fn
        type(c_ptr) :: userData
    end type CUDA_HOST_NODE_PARAMS_v2_st

    type, bind(C) :: CUDA_CONDITIONAL_NODE_PARAMS
        integer(c_int64_t) :: handle
        integer(c_int) :: type
        integer(c_int) :: size
        type(c_ptr) :: phGraph_out
        type(c_ptr) :: ctx
    end type CUDA_CONDITIONAL_NODE_PARAMS

    type, bind(C) :: CUgraphEdgeData_st
        integer(c_signed_char) :: from_port
        integer(c_signed_char) :: to_port
        integer(c_signed_char) :: type
        integer(c_signed_char) :: reserved(5)
    end type CUgraphEdgeData_st

    type, bind(C) :: CUDA_GRAPH_INSTANTIATE_PARAMS_st
        integer(c_int64_t) :: flags
        type(c_ptr) :: hUploadStream
        type(c_ptr) :: hErrNode_out
        integer(c_int) :: result_out
    end type CUDA_GRAPH_INSTANTIATE_PARAMS_st

    type, bind(C) :: CUlaunchMemSyncDomainMap_st
        integer(c_signed_char) :: default_
        integer(c_signed_char) :: remote
    end type CUlaunchMemSyncDomainMap_st

    type, bind(C) :: CUlaunchAttribute_st
        integer(c_int) :: id
        integer(c_int8_t) :: pad(4)   ! computed-size C array (+ padding)
        type(CUlaunchAttributeValue_union) :: value
    end type CUlaunchAttribute_st

    type, bind(C) :: CUlaunchConfig_st
        integer(c_int) :: gridDimX
        integer(c_int) :: gridDimY
        integer(c_int) :: gridDimZ
        integer(c_int) :: blockDimX
        integer(c_int) :: blockDimY
        integer(c_int) :: blockDimZ
        integer(c_int) :: sharedMemBytes
        type(c_ptr) :: hStream
        type(c_ptr) :: attrs
        integer(c_int) :: numAttrs
    end type CUlaunchConfig_st

    type, bind(C) :: CUexecAffinitySmCount_st
        integer(c_int) :: val
    end type CUexecAffinitySmCount_st

    type, bind(C) :: CUexecAffinityParam_st
        integer(c_int) :: type
        integer(c_int32_t) :: param(1)   ! C union / anonymous struct
    end type CUexecAffinityParam_st

    type, bind(C) :: CUctxCigParam_st
        integer(c_int) :: sharedDataType
        type(c_ptr) :: sharedData
    end type CUctxCigParam_st

    type, bind(C) :: CUctxCreateParams_st
        type(c_ptr) :: execAffinityParams
        integer(c_int) :: numExecAffinityParams
        type(c_ptr) :: cigParams
    end type CUctxCreateParams_st

    type, bind(C) :: CUlibraryHostUniversalFunctionAndDataTable_st
        type(c_ptr) :: functionTable
        integer(c_size_t) :: functionWindowSize
        type(c_ptr) :: dataTable
        integer(c_size_t) :: dataWindowSize
    end type CUlibraryHostUniversalFunctionAndDataTable_st

    type, bind(C) :: CUDA_MEMCPY2D_st
        integer(c_size_t) :: srcXInBytes
        integer(c_size_t) :: srcY
        integer(c_int) :: srcMemoryType
        type(c_ptr) :: srcHost
        integer(c_long_long) :: srcDevice
        type(c_ptr) :: srcArray
        integer(c_size_t) :: srcPitch
        integer(c_size_t) :: dstXInBytes
        integer(c_size_t) :: dstY
        integer(c_int) :: dstMemoryType
        type(c_ptr) :: dstHost
        integer(c_long_long) :: dstDevice
        type(c_ptr) :: dstArray
        integer(c_size_t) :: dstPitch
        integer(c_size_t) :: WidthInBytes
        integer(c_size_t) :: Height
    end type CUDA_MEMCPY2D_st

    type, bind(C) :: CUDA_MEMCPY3D_st
        integer(c_size_t) :: srcXInBytes
        integer(c_size_t) :: srcY
        integer(c_size_t) :: srcZ
        integer(c_size_t) :: srcLOD
        integer(c_int) :: srcMemoryType
        type(c_ptr) :: srcHost
        integer(c_long_long) :: srcDevice
        type(c_ptr) :: srcArray
        type(c_ptr) :: reserved0
        integer(c_size_t) :: srcPitch
        integer(c_size_t) :: srcHeight
        integer(c_size_t) :: dstXInBytes
        integer(c_size_t) :: dstY
        integer(c_size_t) :: dstZ
        integer(c_size_t) :: dstLOD
        integer(c_int) :: dstMemoryType
        type(c_ptr) :: dstHost
        integer(c_long_long) :: dstDevice
        type(c_ptr) :: dstArray
        type(c_ptr) :: reserved1
        integer(c_size_t) :: dstPitch
        integer(c_size_t) :: dstHeight
        integer(c_size_t) :: WidthInBytes
        integer(c_size_t) :: Height
        integer(c_size_t) :: Depth
    end type CUDA_MEMCPY3D_st

    type, bind(C) :: CUDA_MEMCPY3D_PEER_st
        integer(c_size_t) :: srcXInBytes
        integer(c_size_t) :: srcY
        integer(c_size_t) :: srcZ
        integer(c_size_t) :: srcLOD
        integer(c_int) :: srcMemoryType
        type(c_ptr) :: srcHost
        integer(c_long_long) :: srcDevice
        type(c_ptr) :: srcArray
        type(c_ptr) :: srcContext
        integer(c_size_t) :: srcPitch
        integer(c_size_t) :: srcHeight
        integer(c_size_t) :: dstXInBytes
        integer(c_size_t) :: dstY
        integer(c_size_t) :: dstZ
        integer(c_size_t) :: dstLOD
        integer(c_int) :: dstMemoryType
        type(c_ptr) :: dstHost
        integer(c_long_long) :: dstDevice
        type(c_ptr) :: dstArray
        type(c_ptr) :: dstContext
        integer(c_size_t) :: dstPitch
        integer(c_size_t) :: dstHeight
        integer(c_size_t) :: WidthInBytes
        integer(c_size_t) :: Height
        integer(c_size_t) :: Depth
    end type CUDA_MEMCPY3D_PEER_st

    type, bind(C) :: CUDA_MEMCPY_NODE_PARAMS_st
        integer(c_int) :: flags
        integer(c_int) :: reserved
        type(c_ptr) :: copyCtx
        type(CUDA_MEMCPY3D_st) :: copyParams
    end type CUDA_MEMCPY_NODE_PARAMS_st

    type, bind(C) :: CUDA_ARRAY_DESCRIPTOR_st
        integer(c_size_t) :: Width
        integer(c_size_t) :: Height
        integer(c_int) :: Format
        integer(c_int) :: NumChannels
    end type CUDA_ARRAY_DESCRIPTOR_st

    type, bind(C) :: CUDA_ARRAY3D_DESCRIPTOR_st
        integer(c_size_t) :: Width
        integer(c_size_t) :: Height
        integer(c_size_t) :: Depth
        integer(c_int) :: Format
        integer(c_int) :: NumChannels
        integer(c_int) :: Flags
    end type CUDA_ARRAY3D_DESCRIPTOR_st

    type, bind(C) :: CUDA_ARRAY_SPARSE_PROPERTIES_st
        integer(c_int32_t) :: tileExtent(3)   ! C union / anonymous struct
        integer(c_int) :: miptailFirstLevel
        integer(c_long_long) :: miptailSize
        integer(c_int) :: flags
        integer(c_int) :: reserved(4)
    end type CUDA_ARRAY_SPARSE_PROPERTIES_st

    type, bind(C) :: CUDA_ARRAY_MEMORY_REQUIREMENTS_st
        integer(c_size_t) :: size
        integer(c_size_t) :: alignment
        integer(c_int) :: reserved(4)
    end type CUDA_ARRAY_MEMORY_REQUIREMENTS_st

    type, bind(C) :: CUDA_RESOURCE_DESC_st
        integer(c_int) :: resType
        integer(c_int64_t) :: res(16)   ! C union / anonymous struct
        integer(c_int) :: flags
    end type CUDA_RESOURCE_DESC_st

    type, bind(C) :: CUDA_TEXTURE_DESC_st
        integer(c_int) :: addressMode(3)
        integer(c_int) :: filterMode
        integer(c_int) :: flags
        integer(c_int) :: maxAnisotropy
        integer(c_int) :: mipmapFilterMode
        real(c_float) :: mipmapLevelBias
        real(c_float) :: minMipmapLevelClamp
        real(c_float) :: maxMipmapLevelClamp
        real(c_float) :: borderColor(4)
        integer(c_int) :: reserved(12)
    end type CUDA_TEXTURE_DESC_st

    type, bind(C) :: CUDA_RESOURCE_VIEW_DESC_st
        integer(c_int) :: format
        integer(c_size_t) :: width
        integer(c_size_t) :: height
        integer(c_size_t) :: depth
        integer(c_int) :: firstMipmapLevel
        integer(c_int) :: lastMipmapLevel
        integer(c_int) :: firstLayer
        integer(c_int) :: lastLayer
        integer(c_int) :: reserved(16)
    end type CUDA_RESOURCE_VIEW_DESC_st

    type, bind(C) :: CUDA_POINTER_ATTRIBUTE_P2P_TOKENS_st
        integer(c_long_long) :: p2pToken
        integer(c_int) :: vaSpaceToken
    end type CUDA_POINTER_ATTRIBUTE_P2P_TOKENS_st

    type, bind(C) :: CUDA_LAUNCH_PARAMS_st
        type(c_ptr) :: function
        integer(c_int) :: gridDimX
        integer(c_int) :: gridDimY
        integer(c_int) :: gridDimZ
        integer(c_int) :: blockDimX
        integer(c_int) :: blockDimY
        integer(c_int) :: blockDimZ
        integer(c_int) :: sharedMemBytes
        type(c_ptr) :: hStream
        type(c_ptr) :: kernelParams
    end type CUDA_LAUNCH_PARAMS_st

    type, bind(C) :: CUDA_EXTERNAL_MEMORY_HANDLE_DESC_st
        integer(c_int) :: type
        integer(c_int64_t) :: handle(2)   ! C union / anonymous struct
        integer(c_long_long) :: size
        integer(c_int) :: flags
        integer(c_int) :: reserved(16)
    end type CUDA_EXTERNAL_MEMORY_HANDLE_DESC_st

    type, bind(C) :: CUDA_EXTERNAL_MEMORY_BUFFER_DESC_st
        integer(c_long_long) :: offset
        integer(c_long_long) :: size
        integer(c_int) :: flags
        integer(c_int) :: reserved(16)
    end type CUDA_EXTERNAL_MEMORY_BUFFER_DESC_st

    type, bind(C) :: CUDA_EXTERNAL_MEMORY_MIPMAPPED_ARRAY_DESC_st
        integer(c_long_long) :: offset
        type(CUDA_ARRAY3D_DESCRIPTOR_st) :: arrayDesc
        integer(c_int) :: numLevels
        integer(c_int) :: reserved(16)
    end type CUDA_EXTERNAL_MEMORY_MIPMAPPED_ARRAY_DESC_st

    type, bind(C) :: CUDA_EXTERNAL_SEMAPHORE_HANDLE_DESC_st
        integer(c_int) :: type
        integer(c_int64_t) :: handle(2)   ! C union / anonymous struct
        integer(c_int) :: flags
        integer(c_int) :: reserved(16)
    end type CUDA_EXTERNAL_SEMAPHORE_HANDLE_DESC_st

    type, bind(C) :: CUDA_EXTERNAL_SEMAPHORE_SIGNAL_PARAMS_st
        integer(c_int64_t) :: params(9)   ! C union / anonymous struct
        integer(c_int) :: flags
        integer(c_int) :: reserved(16)
    end type CUDA_EXTERNAL_SEMAPHORE_SIGNAL_PARAMS_st

    type, bind(C) :: CUDA_EXTERNAL_SEMAPHORE_WAIT_PARAMS_st
        integer(c_int64_t) :: params(9)   ! C union / anonymous struct
        integer(c_int) :: flags
        integer(c_int) :: reserved(16)
    end type CUDA_EXTERNAL_SEMAPHORE_WAIT_PARAMS_st

    type, bind(C) :: CUDA_EXT_SEM_SIGNAL_NODE_PARAMS_st
        type(c_ptr) :: extSemArray
        type(c_ptr) :: paramsArray
        integer(c_int) :: numExtSems
    end type CUDA_EXT_SEM_SIGNAL_NODE_PARAMS_st

    type, bind(C) :: CUDA_EXT_SEM_SIGNAL_NODE_PARAMS_v2_st
        type(c_ptr) :: extSemArray
        type(c_ptr) :: paramsArray
        integer(c_int) :: numExtSems
    end type CUDA_EXT_SEM_SIGNAL_NODE_PARAMS_v2_st

    type, bind(C) :: CUDA_EXT_SEM_WAIT_NODE_PARAMS_st
        type(c_ptr) :: extSemArray
        type(c_ptr) :: paramsArray
        integer(c_int) :: numExtSems
    end type CUDA_EXT_SEM_WAIT_NODE_PARAMS_st

    type, bind(C) :: CUDA_EXT_SEM_WAIT_NODE_PARAMS_v2_st
        type(c_ptr) :: extSemArray
        type(c_ptr) :: paramsArray
        integer(c_int) :: numExtSems
    end type CUDA_EXT_SEM_WAIT_NODE_PARAMS_v2_st

    type, bind(C) :: CUarrayMapInfo_st
        integer(c_int) :: resourceType
        integer(c_int64_t) :: resource(1)   ! C union / anonymous struct
        integer(c_int) :: subresourceType
        integer(c_int64_t) :: subresource(4)   ! C union / anonymous struct
        integer(c_int) :: memOperationType
        integer(c_int) :: memHandleType
        integer(c_int64_t) :: memHandle(1)   ! C union / anonymous struct
        integer(c_long_long) :: offset
        integer(c_int) :: deviceBitMask
        integer(c_int) :: flags
        integer(c_int) :: reserved(2)
    end type CUarrayMapInfo_st

    type, bind(C) :: CUmemLocation_st
        integer(c_int) :: type
        integer(c_int) :: id
    end type CUmemLocation_st

    type, bind(C) :: CUmemAllocationProp_st
        integer(c_int) :: type
        integer(c_int) :: requestedHandleTypes
        type(CUmemLocation_st) :: location
        type(c_ptr) :: win32HandleMetaData
        integer(c_int64_t) :: allocFlags(1)   ! C union / anonymous struct
    end type CUmemAllocationProp_st

    type, bind(C) :: CUmulticastObjectProp_st
        integer(c_int) :: numDevices
        integer(c_size_t) :: size
        integer(c_long_long) :: handleTypes
        integer(c_long_long) :: flags
    end type CUmulticastObjectProp_st

    type, bind(C) :: CUmemAccessDesc_st
        type(CUmemLocation_st) :: location
        integer(c_int) :: flags
    end type CUmemAccessDesc_st

    type, bind(C) :: CUgraphExecUpdateResultInfo_st
        integer(c_int) :: result
        type(c_ptr) :: errorNode
        type(c_ptr) :: errorFromNode
    end type CUgraphExecUpdateResultInfo_st

    type, bind(C) :: CUmemPoolProps_st
        integer(c_int) :: allocType
        integer(c_int) :: handleTypes
        type(CUmemLocation_st) :: location
        type(c_ptr) :: win32SecurityAttributes
        integer(c_size_t) :: maxSize
        integer(c_short) :: usage
        integer(c_signed_char) :: reserved(54)
    end type CUmemPoolProps_st

    type, bind(C) :: CUmemPoolPtrExportData_st
        integer(c_signed_char) :: reserved(64)
    end type CUmemPoolPtrExportData_st

    type, bind(C) :: CUmemcpyAttributes_st
        integer(c_int) :: srcAccessOrder
        type(CUmemLocation_st) :: srcLocHint
        type(CUmemLocation_st) :: dstLocHint
        integer(c_int) :: flags
    end type CUmemcpyAttributes_st

    type, bind(C) :: CUoffset3D_st
        integer(c_size_t) :: x
        integer(c_size_t) :: y
        integer(c_size_t) :: z
    end type CUoffset3D_st

    type, bind(C) :: CUextent3D_st
        integer(c_size_t) :: width
        integer(c_size_t) :: height
        integer(c_size_t) :: depth
    end type CUextent3D_st

    type, bind(C) :: CUmemcpy3DOperand_st
        integer(c_int) :: type
        integer(c_int64_t) :: op(4)   ! C union / anonymous struct
    end type CUmemcpy3DOperand_st

    type, bind(C) :: CUDA_MEMCPY3D_BATCH_OP_st
        type(CUmemcpy3DOperand_st) :: src
        type(CUmemcpy3DOperand_st) :: dst
        type(CUextent3D_st) :: extent
        integer(c_int) :: srcAccessOrder
        integer(c_int) :: flags
    end type CUDA_MEMCPY3D_BATCH_OP_st

    type, bind(C) :: CUDA_MEM_ALLOC_NODE_PARAMS_v1_st
        type(CUmemPoolProps_st) :: poolProps
        type(c_ptr) :: accessDescs
        integer(c_size_t) :: accessDescCount
        integer(c_size_t) :: bytesize
        integer(c_long_long) :: dptr
    end type CUDA_MEM_ALLOC_NODE_PARAMS_v1_st

    type, bind(C) :: CUDA_MEM_ALLOC_NODE_PARAMS_v2_st
        type(CUmemPoolProps_st) :: poolProps
        type(c_ptr) :: accessDescs
        integer(c_size_t) :: accessDescCount
        integer(c_size_t) :: bytesize
        integer(c_long_long) :: dptr
    end type CUDA_MEM_ALLOC_NODE_PARAMS_v2_st

    type, bind(C) :: CUDA_MEM_FREE_NODE_PARAMS_st
        integer(c_long_long) :: dptr
    end type CUDA_MEM_FREE_NODE_PARAMS_st

    type, bind(C) :: CUDA_CHILD_GRAPH_NODE_PARAMS_st
        type(c_ptr) :: graph
        integer(c_int) :: ownership
    end type CUDA_CHILD_GRAPH_NODE_PARAMS_st

    type, bind(C) :: CUDA_EVENT_RECORD_NODE_PARAMS_st
        type(c_ptr) :: event
    end type CUDA_EVENT_RECORD_NODE_PARAMS_st

    type, bind(C) :: CUDA_EVENT_WAIT_NODE_PARAMS_st
        type(c_ptr) :: event
    end type CUDA_EVENT_WAIT_NODE_PARAMS_st

    type, bind(C) :: CUgraphNodeParams_st
        integer(c_int) :: type
        integer(c_int) :: reserved0(3)
        integer(c_int8_t) :: anon2(232)   ! anonymous C union (+ padding)
        integer(c_long_long) :: reserved2
    end type CUgraphNodeParams_st

    type, bind(C) :: CUcheckpointLockArgs_st
        integer(c_int) :: timeoutMs
        integer(c_int) :: reserved0
        integer(c_int64_t) :: reserved1(7)
    end type CUcheckpointLockArgs_st

    type, bind(C) :: CUcheckpointCheckpointArgs_st
        integer(c_int64_t) :: reserved(8)
    end type CUcheckpointCheckpointArgs_st

    type, bind(C) :: CUcheckpointRestoreArgs_st
        integer(c_int64_t) :: reserved(8)
    end type CUcheckpointRestoreArgs_st

    type, bind(C) :: CUcheckpointUnlockArgs_st
        integer(c_int64_t) :: reserved(8)
    end type CUcheckpointUnlockArgs_st

    type, bind(C) :: CUmemDecompressParams_st
        integer(c_size_t) :: srcNumBytes
        integer(c_size_t) :: dstNumBytes
        type(c_ptr) :: dstActBytes
        type(c_ptr) :: src
        type(c_ptr) :: dst
        integer(c_int) :: algo
        integer(c_signed_char) :: padding(20)
    end type CUmemDecompressParams_st

    type, bind(C) :: CUdevSmResource_st
        integer(c_int) :: smCount
    end type CUdevSmResource_st

    type, bind(C) :: CUdevResource_st
        integer(c_int) :: type
        integer(c_signed_char) :: x_internal_padding(92)
        integer(c_int8_t) :: anon2(48)   ! anonymous C union (+ padding)
    end type CUdevResource_st

    ! ======================================================================
    !  C entry points
    ! ======================================================================
    interface

        integer(c_int) function cuArray3DCreate(pHandle, pAllocateArray) &
                bind(C, name="cuArray3DCreate_v2")   ! header aliases cuArray3DCreate -> cuArray3DCreate_v2
            import
            type(c_ptr), intent(out) :: pHandle
            type(CUDA_ARRAY3D_DESCRIPTOR_st), intent(in) :: pAllocateArray
        end function cuArray3DCreate

        integer(c_int) function cuArray3DGetDescriptor(pArrayDescriptor, hArray) &
                bind(C, name="cuArray3DGetDescriptor_v2")   ! header aliases cuArray3DGetDescriptor -> cuArray3DGetDescriptor_v2
            import
            type(CUDA_ARRAY3D_DESCRIPTOR_st), intent(inout) :: pArrayDescriptor
            type(c_ptr), value :: hArray
        end function cuArray3DGetDescriptor

        integer(c_int) function cuArrayCreate(pHandle, pAllocateArray) &
                bind(C, name="cuArrayCreate_v2")   ! header aliases cuArrayCreate -> cuArrayCreate_v2
            import
            type(c_ptr), intent(out) :: pHandle
            type(CUDA_ARRAY_DESCRIPTOR_st), intent(in) :: pAllocateArray
        end function cuArrayCreate

        integer(c_int) function cuArrayDestroy(hArray) &
                bind(C, name="cuArrayDestroy")
            import
            type(c_ptr), value :: hArray
        end function cuArrayDestroy

        integer(c_int) function cuArrayGetDescriptor(pArrayDescriptor, hArray) &
                bind(C, name="cuArrayGetDescriptor_v2")   ! header aliases cuArrayGetDescriptor -> cuArrayGetDescriptor_v2
            import
            type(CUDA_ARRAY_DESCRIPTOR_st), intent(inout) :: pArrayDescriptor
            type(c_ptr), value :: hArray
        end function cuArrayGetDescriptor

        integer(c_int) function cuArrayGetMemoryRequirements(memoryRequirements, array, device) &
                bind(C, name="cuArrayGetMemoryRequirements")
            import
            type(CUDA_ARRAY_MEMORY_REQUIREMENTS_st), intent(inout) :: memoryRequirements
            type(c_ptr), value :: array
            integer(c_int), value :: device
        end function cuArrayGetMemoryRequirements

        integer(c_int) function cuArrayGetPlane(pPlaneArray, hArray, planeIdx) &
                bind(C, name="cuArrayGetPlane")
            import
            type(c_ptr), intent(out) :: pPlaneArray
            type(c_ptr), value :: hArray
            integer(c_int), value :: planeIdx
        end function cuArrayGetPlane

        integer(c_int) function cuArrayGetSparseProperties(sparseProperties, array) &
                bind(C, name="cuArrayGetSparseProperties")
            import
            type(CUDA_ARRAY_SPARSE_PROPERTIES_st), intent(inout) :: sparseProperties
            type(c_ptr), value :: array
        end function cuArrayGetSparseProperties

        integer(c_int) function cuCheckpointProcessCheckpoint(pid, args) &
                bind(C, name="cuCheckpointProcessCheckpoint")
            import
            integer(c_int), value :: pid
            type(CUcheckpointCheckpointArgs_st), intent(inout) :: args
        end function cuCheckpointProcessCheckpoint

        integer(c_int) function cuCheckpointProcessGetRestoreThreadId(pid, tid) &
                bind(C, name="cuCheckpointProcessGetRestoreThreadId")
            import
            integer(c_int), value :: pid
            integer(c_int), intent(inout) :: tid
        end function cuCheckpointProcessGetRestoreThreadId

        integer(c_int) function cuCheckpointProcessGetState(pid, state) &
                bind(C, name="cuCheckpointProcessGetState")
            import
            integer(c_int), value :: pid
            integer(c_int), intent(out) :: state
        end function cuCheckpointProcessGetState

        integer(c_int) function cuCheckpointProcessLock(pid, args) &
                bind(C, name="cuCheckpointProcessLock")
            import
            integer(c_int), value :: pid
            type(CUcheckpointLockArgs_st), intent(inout) :: args
        end function cuCheckpointProcessLock

        integer(c_int) function cuCheckpointProcessRestore(pid, args) &
                bind(C, name="cuCheckpointProcessRestore")
            import
            integer(c_int), value :: pid
            type(CUcheckpointRestoreArgs_st), intent(inout) :: args
        end function cuCheckpointProcessRestore

        integer(c_int) function cuCheckpointProcessUnlock(pid, args) &
                bind(C, name="cuCheckpointProcessUnlock")
            import
            integer(c_int), value :: pid
            type(CUcheckpointUnlockArgs_st), intent(inout) :: args
        end function cuCheckpointProcessUnlock

        integer(c_int) function cuCoredumpGetAttribute(attrib, value, size) &
                bind(C, name="cuCoredumpGetAttribute")
            import
            integer(c_int), value :: attrib
            type(c_ptr), value :: value
            integer(c_size_t), intent(inout) :: size
        end function cuCoredumpGetAttribute

        integer(c_int) function cuCoredumpGetAttributeGlobal(attrib, value, size) &
                bind(C, name="cuCoredumpGetAttributeGlobal")
            import
            integer(c_int), value :: attrib
            type(c_ptr), value :: value
            integer(c_size_t), intent(inout) :: size
        end function cuCoredumpGetAttributeGlobal

        integer(c_int) function cuCoredumpSetAttribute(attrib, value, size) &
                bind(C, name="cuCoredumpSetAttribute")
            import
            integer(c_int), value :: attrib
            type(c_ptr), value :: value
            integer(c_size_t), intent(inout) :: size
        end function cuCoredumpSetAttribute

        integer(c_int) function cuCoredumpSetAttributeGlobal(attrib, value, size) &
                bind(C, name="cuCoredumpSetAttributeGlobal")
            import
            integer(c_int), value :: attrib
            type(c_ptr), value :: value
            integer(c_size_t), intent(inout) :: size
        end function cuCoredumpSetAttributeGlobal

        integer(c_int) function cuCtxAttach(pctx, flags) &
                bind(C, name="cuCtxAttach")
            import
            type(c_ptr), intent(out) :: pctx
            integer(c_int), value :: flags
        end function cuCtxAttach

        integer(c_int) function cuCtxCreate(pctx, flags, dev) &
                bind(C, name="cuCtxCreate_v2")   ! header aliases cuCtxCreate -> cuCtxCreate_v2
            import
            type(c_ptr), intent(out) :: pctx
            integer(c_int), value :: flags
            integer(c_int), value :: dev
        end function cuCtxCreate

        integer(c_int) function cuCtxCreate_v3(pctx, paramsArray, numParams, flags, dev) &
                bind(C, name="cuCtxCreate_v3")
            import
            type(c_ptr), intent(out) :: pctx
            type(CUexecAffinityParam_st), intent(inout) :: paramsArray
            integer(c_int), value :: numParams
            integer(c_int), value :: flags
            integer(c_int), value :: dev
        end function cuCtxCreate_v3

        integer(c_int) function cuCtxCreate_v4(pctx, ctxCreateParams, flags, dev) &
                bind(C, name="cuCtxCreate_v4")
            import
            type(c_ptr), intent(out) :: pctx
            type(CUctxCreateParams_st), intent(inout) :: ctxCreateParams
            integer(c_int), value :: flags
            integer(c_int), value :: dev
        end function cuCtxCreate_v4

        integer(c_int) function cuCtxDestroy(ctx) &
                bind(C, name="cuCtxDestroy_v2")   ! header aliases cuCtxDestroy -> cuCtxDestroy_v2
            import
            type(c_ptr), value :: ctx
        end function cuCtxDestroy

        integer(c_int) function cuCtxDetach(ctx) &
                bind(C, name="cuCtxDetach")
            import
            type(c_ptr), value :: ctx
        end function cuCtxDetach

        integer(c_int) function cuCtxDisablePeerAccess(peerContext) &
                bind(C, name="cuCtxDisablePeerAccess")
            import
            type(c_ptr), value :: peerContext
        end function cuCtxDisablePeerAccess

        integer(c_int) function cuCtxEnablePeerAccess(peerContext, Flags) &
                bind(C, name="cuCtxEnablePeerAccess")
            import
            type(c_ptr), value :: peerContext
            integer(c_int), value :: Flags
        end function cuCtxEnablePeerAccess

        integer(c_int) function cuCtxFromGreenCtx(pContext, hCtx) &
                bind(C, name="cuCtxFromGreenCtx")
            import
            type(c_ptr), intent(out) :: pContext
            type(c_ptr), value :: hCtx
        end function cuCtxFromGreenCtx

        integer(c_int) function cuCtxGetApiVersion(ctx, version) &
                bind(C, name="cuCtxGetApiVersion")
            import
            type(c_ptr), value :: ctx
            integer(c_int), intent(inout) :: version
        end function cuCtxGetApiVersion

        integer(c_int) function cuCtxGetCacheConfig(pconfig) &
                bind(C, name="cuCtxGetCacheConfig")
            import
            integer(c_int), intent(out) :: pconfig
        end function cuCtxGetCacheConfig

        integer(c_int) function cuCtxGetCurrent(pctx) &
                bind(C, name="cuCtxGetCurrent")
            import
            type(c_ptr), intent(out) :: pctx
        end function cuCtxGetCurrent

        integer(c_int) function cuCtxGetDevResource(hCtx, resource, type) &
                bind(C, name="cuCtxGetDevResource")
            import
            type(c_ptr), value :: hCtx
            type(CUdevResource_st), intent(inout) :: resource
            integer(c_int), value :: type
        end function cuCtxGetDevResource

        integer(c_int) function cuCtxGetDevice(device) &
                bind(C, name="cuCtxGetDevice")
            import
            integer(c_int), intent(inout) :: device
        end function cuCtxGetDevice

        integer(c_int) function cuCtxGetExecAffinity(pExecAffinity, type) &
                bind(C, name="cuCtxGetExecAffinity")
            import
            type(CUexecAffinityParam_st), intent(inout) :: pExecAffinity
            integer(c_int), value :: type
        end function cuCtxGetExecAffinity

        integer(c_int) function cuCtxGetFlags(flags) &
                bind(C, name="cuCtxGetFlags")
            import
            integer(c_int), intent(inout) :: flags
        end function cuCtxGetFlags

        integer(c_int) function cuCtxGetId(ctx, ctxId) &
                bind(C, name="cuCtxGetId")
            import
            type(c_ptr), value :: ctx
            integer(c_long_long), intent(inout) :: ctxId
        end function cuCtxGetId

        integer(c_int) function cuCtxGetLimit(pvalue, limit) &
                bind(C, name="cuCtxGetLimit")
            import
            integer(c_size_t), intent(inout) :: pvalue
            integer(c_int), value :: limit
        end function cuCtxGetLimit

        integer(c_int) function cuCtxGetSharedMemConfig(pConfig) &
                bind(C, name="cuCtxGetSharedMemConfig")
            import
            integer(c_int), intent(out) :: pConfig
        end function cuCtxGetSharedMemConfig

        integer(c_int) function cuCtxGetStreamPriorityRange(leastPriority, greatestPriority) &
                bind(C, name="cuCtxGetStreamPriorityRange")
            import
            integer(c_int), intent(inout) :: leastPriority
            integer(c_int), intent(inout) :: greatestPriority
        end function cuCtxGetStreamPriorityRange

        integer(c_int) function cuCtxPopCurrent(pctx) &
                bind(C, name="cuCtxPopCurrent_v2")   ! header aliases cuCtxPopCurrent -> cuCtxPopCurrent_v2
            import
            type(c_ptr), intent(out) :: pctx
        end function cuCtxPopCurrent

        integer(c_int) function cuCtxPushCurrent(ctx) &
                bind(C, name="cuCtxPushCurrent_v2")   ! header aliases cuCtxPushCurrent -> cuCtxPushCurrent_v2
            import
            type(c_ptr), value :: ctx
        end function cuCtxPushCurrent

        integer(c_int) function cuCtxRecordEvent(hCtx, hEvent) &
                bind(C, name="cuCtxRecordEvent")
            import
            type(c_ptr), value :: hCtx
            type(c_ptr), value :: hEvent
        end function cuCtxRecordEvent

        integer(c_int) function cuCtxResetPersistingL2Cache() &
                bind(C, name="cuCtxResetPersistingL2Cache")
            import
        end function cuCtxResetPersistingL2Cache

        integer(c_int) function cuCtxSetCacheConfig(config) &
                bind(C, name="cuCtxSetCacheConfig")
            import
            integer(c_int), value :: config
        end function cuCtxSetCacheConfig

        integer(c_int) function cuCtxSetCurrent(ctx) &
                bind(C, name="cuCtxSetCurrent")
            import
            type(c_ptr), value :: ctx
        end function cuCtxSetCurrent

        integer(c_int) function cuCtxSetFlags(flags) &
                bind(C, name="cuCtxSetFlags")
            import
            integer(c_int), value :: flags
        end function cuCtxSetFlags

        integer(c_int) function cuCtxSetLimit(limit, value) &
                bind(C, name="cuCtxSetLimit")
            import
            integer(c_int), value :: limit
            integer(c_size_t), value :: value
        end function cuCtxSetLimit

        integer(c_int) function cuCtxSetSharedMemConfig(config) &
                bind(C, name="cuCtxSetSharedMemConfig")
            import
            integer(c_int), value :: config
        end function cuCtxSetSharedMemConfig

        integer(c_int) function cuCtxSynchronize() &
                bind(C, name="cuCtxSynchronize")
            import
        end function cuCtxSynchronize

        integer(c_int) function cuCtxWaitEvent(hCtx, hEvent) &
                bind(C, name="cuCtxWaitEvent")
            import
            type(c_ptr), value :: hCtx
            type(c_ptr), value :: hEvent
        end function cuCtxWaitEvent

        integer(c_int) function cuDestroyExternalMemory(extMem) &
                bind(C, name="cuDestroyExternalMemory")
            import
            type(c_ptr), value :: extMem
        end function cuDestroyExternalMemory

        integer(c_int) function cuDestroyExternalSemaphore(extSem) &
                bind(C, name="cuDestroyExternalSemaphore")
            import
            type(c_ptr), value :: extSem
        end function cuDestroyExternalSemaphore

        integer(c_int) function cuDevResourceGenerateDesc(phDesc, resources, nbResources) &
                bind(C, name="cuDevResourceGenerateDesc")
            import
            type(c_ptr), intent(out) :: phDesc
            type(CUdevResource_st), intent(inout) :: resources
            integer(c_int), value :: nbResources
        end function cuDevResourceGenerateDesc

        integer(c_int) function cuDevSmResourceSplitByCount(result, nbGroups, input, remaining, useFlags, minCount) &
                bind(C, name="cuDevSmResourceSplitByCount")
            import
            type(CUdevResource_st), intent(inout) :: result
            integer(c_int), intent(inout) :: nbGroups
            type(CUdevResource_st), intent(in) :: input
            type(CUdevResource_st), intent(inout) :: remaining
            integer(c_int), value :: useFlags
            integer(c_int), value :: minCount
        end function cuDevSmResourceSplitByCount

        integer(c_int) function cuDeviceCanAccessPeer(canAccessPeer, dev, peerDev) &
                bind(C, name="cuDeviceCanAccessPeer")
            import
            integer(c_int), intent(inout) :: canAccessPeer
            integer(c_int), value :: dev
            integer(c_int), value :: peerDev
        end function cuDeviceCanAccessPeer

        integer(c_int) function cuDeviceComputeCapability(major, minor, dev) &
                bind(C, name="cuDeviceComputeCapability")
            import
            integer(c_int), intent(inout) :: major
            integer(c_int), intent(inout) :: minor
            integer(c_int), value :: dev
        end function cuDeviceComputeCapability

        integer(c_int) function cuDeviceGet(device, ordinal) &
                bind(C, name="cuDeviceGet")
            import
            integer(c_int), intent(inout) :: device
            integer(c_int), value :: ordinal
        end function cuDeviceGet

        integer(c_int) function cuDeviceGetAttribute(pi, attrib, dev) &
                bind(C, name="cuDeviceGetAttribute")
            import
            integer(c_int), intent(inout) :: pi
            integer(c_int), value :: attrib
            integer(c_int), value :: dev
        end function cuDeviceGetAttribute

        integer(c_int) function cuDeviceGetByPCIBusId(dev, pciBusId) &
                bind(C, name="cuDeviceGetByPCIBusId")
            import
            integer(c_int), intent(inout) :: dev
            character(kind=c_char), dimension(*), intent(in) :: pciBusId
        end function cuDeviceGetByPCIBusId

        integer(c_int) function cuDeviceGetCount(count) &
                bind(C, name="cuDeviceGetCount")
            import
            integer(c_int), intent(inout) :: count
        end function cuDeviceGetCount

        integer(c_int) function cuDeviceGetDefaultMemPool(pool_out, dev) &
                bind(C, name="cuDeviceGetDefaultMemPool")
            import
            type(c_ptr), intent(out) :: pool_out
            integer(c_int), value :: dev
        end function cuDeviceGetDefaultMemPool

        integer(c_int) function cuDeviceGetDevResource(device, resource, type) &
                bind(C, name="cuDeviceGetDevResource")
            import
            integer(c_int), value :: device
            type(CUdevResource_st), intent(inout) :: resource
            integer(c_int), value :: type
        end function cuDeviceGetDevResource

        integer(c_int) function cuDeviceGetExecAffinitySupport(pi, type, dev) &
                bind(C, name="cuDeviceGetExecAffinitySupport")
            import
            integer(c_int), intent(inout) :: pi
            integer(c_int), value :: type
            integer(c_int), value :: dev
        end function cuDeviceGetExecAffinitySupport

        integer(c_int) function cuDeviceGetGraphMemAttribute(device, attr, value) &
                bind(C, name="cuDeviceGetGraphMemAttribute")
            import
            integer(c_int), value :: device
            integer(c_int), value :: attr
            type(c_ptr), value :: value
        end function cuDeviceGetGraphMemAttribute

        integer(c_int) function cuDeviceGetLuid(luid, deviceNodeMask, dev) &
                bind(C, name="cuDeviceGetLuid")
            import
            character(kind=c_char), dimension(*), intent(in) :: luid
            integer(c_int), intent(inout) :: deviceNodeMask
            integer(c_int), value :: dev
        end function cuDeviceGetLuid

        integer(c_int) function cuDeviceGetMemPool(pool, dev) &
                bind(C, name="cuDeviceGetMemPool")
            import
            type(c_ptr), intent(out) :: pool
            integer(c_int), value :: dev
        end function cuDeviceGetMemPool

        integer(c_int) function cuDeviceGetName(name, len, dev) &
                bind(C, name="cuDeviceGetName")
            import
            character(kind=c_char), dimension(*), intent(in) :: name
            integer(c_int), value :: len
            integer(c_int), value :: dev
        end function cuDeviceGetName

        integer(c_int) function cuDeviceGetNvSciSyncAttributes(nvSciSyncAttrList, dev, flags) &
                bind(C, name="cuDeviceGetNvSciSyncAttributes")
            import
            type(c_ptr), value :: nvSciSyncAttrList
            integer(c_int), value :: dev
            integer(c_int), value :: flags
        end function cuDeviceGetNvSciSyncAttributes

        integer(c_int) function cuDeviceGetP2PAttribute(value, attrib, srcDevice, dstDevice) &
                bind(C, name="cuDeviceGetP2PAttribute")
            import
            integer(c_int), intent(inout) :: value
            integer(c_int), value :: attrib
            integer(c_int), value :: srcDevice
            integer(c_int), value :: dstDevice
        end function cuDeviceGetP2PAttribute

        integer(c_int) function cuDeviceGetPCIBusId(pciBusId, len, dev) &
                bind(C, name="cuDeviceGetPCIBusId")
            import
            character(kind=c_char), dimension(*), intent(in) :: pciBusId
            integer(c_int), value :: len
            integer(c_int), value :: dev
        end function cuDeviceGetPCIBusId

        integer(c_int) function cuDeviceGetProperties(prop, dev) &
                bind(C, name="cuDeviceGetProperties")
            import
            type(CUdevprop_st), intent(inout) :: prop
            integer(c_int), value :: dev
        end function cuDeviceGetProperties

        integer(c_int) function cuDeviceGetTexture1DLinearMaxWidth(maxWidthInElements, format, numChannels, dev) &
                bind(C, name="cuDeviceGetTexture1DLinearMaxWidth")
            import
            integer(c_size_t), intent(inout) :: maxWidthInElements
            integer(c_int), value :: format
            integer(c_int), value :: numChannels
            integer(c_int), value :: dev
        end function cuDeviceGetTexture1DLinearMaxWidth

        integer(c_int) function cuDeviceGetUuid(uuid, dev) &
                bind(C, name="cuDeviceGetUuid")
            import
            type(CUuuid_st), intent(inout) :: uuid
            integer(c_int), value :: dev
        end function cuDeviceGetUuid

        integer(c_int) function cuDeviceGetUuid_v2(uuid, dev) &
                bind(C, name="cuDeviceGetUuid_v2")
            import
            type(CUuuid_st), intent(inout) :: uuid
            integer(c_int), value :: dev
        end function cuDeviceGetUuid_v2

        integer(c_int) function cuDeviceGraphMemTrim(device) &
                bind(C, name="cuDeviceGraphMemTrim")
            import
            integer(c_int), value :: device
        end function cuDeviceGraphMemTrim

        integer(c_int) function cuDevicePrimaryCtxGetState(dev, flags, active) &
                bind(C, name="cuDevicePrimaryCtxGetState")
            import
            integer(c_int), value :: dev
            integer(c_int), intent(inout) :: flags
            integer(c_int), intent(inout) :: active
        end function cuDevicePrimaryCtxGetState

        integer(c_int) function cuDevicePrimaryCtxRelease(dev) &
                bind(C, name="cuDevicePrimaryCtxRelease_v2")   ! header aliases cuDevicePrimaryCtxRelease -> cuDevicePrimaryCtxRelease_v2
            import
            integer(c_int), value :: dev
        end function cuDevicePrimaryCtxRelease

        integer(c_int) function cuDevicePrimaryCtxReset(dev) &
                bind(C, name="cuDevicePrimaryCtxReset_v2")   ! header aliases cuDevicePrimaryCtxReset -> cuDevicePrimaryCtxReset_v2
            import
            integer(c_int), value :: dev
        end function cuDevicePrimaryCtxReset

        integer(c_int) function cuDevicePrimaryCtxRetain(pctx, dev) &
                bind(C, name="cuDevicePrimaryCtxRetain")
            import
            type(c_ptr), intent(out) :: pctx
            integer(c_int), value :: dev
        end function cuDevicePrimaryCtxRetain

        integer(c_int) function cuDevicePrimaryCtxSetFlags(dev, flags) &
                bind(C, name="cuDevicePrimaryCtxSetFlags_v2")   ! header aliases cuDevicePrimaryCtxSetFlags -> cuDevicePrimaryCtxSetFlags_v2
            import
            integer(c_int), value :: dev
            integer(c_int), value :: flags
        end function cuDevicePrimaryCtxSetFlags

        integer(c_int) function cuDeviceRegisterAsyncNotification(device, callbackFunc, userData, callback) &
                bind(C, name="cuDeviceRegisterAsyncNotification")
            import
            integer(c_int), value :: device
            type(c_funptr), value :: callbackFunc
            type(c_ptr), value :: userData
            type(c_ptr), intent(out) :: callback
        end function cuDeviceRegisterAsyncNotification

        integer(c_int) function cuDeviceSetGraphMemAttribute(device, attr, value) &
                bind(C, name="cuDeviceSetGraphMemAttribute")
            import
            integer(c_int), value :: device
            integer(c_int), value :: attr
            type(c_ptr), value :: value
        end function cuDeviceSetGraphMemAttribute

        integer(c_int) function cuDeviceSetMemPool(dev, pool) &
                bind(C, name="cuDeviceSetMemPool")
            import
            integer(c_int), value :: dev
            type(c_ptr), value :: pool
        end function cuDeviceSetMemPool

        integer(c_int) function cuDeviceTotalMem(bytes, dev) &
                bind(C, name="cuDeviceTotalMem_v2")   ! header aliases cuDeviceTotalMem -> cuDeviceTotalMem_v2
            import
            integer(c_size_t), intent(inout) :: bytes
            integer(c_int), value :: dev
        end function cuDeviceTotalMem

        integer(c_int) function cuDeviceUnregisterAsyncNotification(device, callback) &
                bind(C, name="cuDeviceUnregisterAsyncNotification")
            import
            integer(c_int), value :: device
            type(c_ptr), value :: callback
        end function cuDeviceUnregisterAsyncNotification

        integer(c_int) function cuDriverGetVersion(driverVersion) &
                bind(C, name="cuDriverGetVersion")
            import
            integer(c_int), intent(inout) :: driverVersion
        end function cuDriverGetVersion

        integer(c_int) function cuEventCreate(phEvent, Flags) &
                bind(C, name="cuEventCreate")
            import
            type(c_ptr), intent(out) :: phEvent
            integer(c_int), value :: Flags
        end function cuEventCreate

        integer(c_int) function cuEventDestroy(hEvent) &
                bind(C, name="cuEventDestroy_v2")   ! header aliases cuEventDestroy -> cuEventDestroy_v2
            import
            type(c_ptr), value :: hEvent
        end function cuEventDestroy

        integer(c_int) function cuEventElapsedTime(pMilliseconds, hStart, hEnd) &
                bind(C, name="cuEventElapsedTime")
            import
            real(c_float), intent(inout) :: pMilliseconds
            type(c_ptr), value :: hStart
            type(c_ptr), value :: hEnd
        end function cuEventElapsedTime

        integer(c_int) function cuEventElapsedTime_v2(pMilliseconds, hStart, hEnd) &
                bind(C, name="cuEventElapsedTime_v2")
            import
            real(c_float), intent(inout) :: pMilliseconds
            type(c_ptr), value :: hStart
            type(c_ptr), value :: hEnd
        end function cuEventElapsedTime_v2

        integer(c_int) function cuEventQuery(hEvent) &
                bind(C, name="cuEventQuery")
            import
            type(c_ptr), value :: hEvent
        end function cuEventQuery

        integer(c_int) function cuEventRecord(hEvent, hStream) &
                bind(C, name="cuEventRecord")
            import
            type(c_ptr), value :: hEvent
            type(c_ptr), value :: hStream
        end function cuEventRecord

        integer(c_int) function cuEventRecordWithFlags(hEvent, hStream, flags) &
                bind(C, name="cuEventRecordWithFlags")
            import
            type(c_ptr), value :: hEvent
            type(c_ptr), value :: hStream
            integer(c_int), value :: flags
        end function cuEventRecordWithFlags

        integer(c_int) function cuEventSynchronize(hEvent) &
                bind(C, name="cuEventSynchronize")
            import
            type(c_ptr), value :: hEvent
        end function cuEventSynchronize

        integer(c_int) function cuExternalMemoryGetMappedBuffer(devPtr, extMem, bufferDesc) &
                bind(C, name="cuExternalMemoryGetMappedBuffer")
            import
            integer(c_long_long), intent(inout) :: devPtr
            type(c_ptr), value :: extMem
            type(CUDA_EXTERNAL_MEMORY_BUFFER_DESC_st), intent(in) :: bufferDesc
        end function cuExternalMemoryGetMappedBuffer

        integer(c_int) function cuExternalMemoryGetMappedMipmappedArray(mipmap, extMem, mipmapDesc) &
                bind(C, name="cuExternalMemoryGetMappedMipmappedArray")
            import
            type(c_ptr), intent(out) :: mipmap
            type(c_ptr), value :: extMem
            type(CUDA_EXTERNAL_MEMORY_MIPMAPPED_ARRAY_DESC_st), intent(in) :: mipmapDesc
        end function cuExternalMemoryGetMappedMipmappedArray

        integer(c_int) function cuFlushGPUDirectRDMAWrites(target, scope) &
                bind(C, name="cuFlushGPUDirectRDMAWrites")
            import
            integer(c_int), value :: target
            integer(c_int), value :: scope
        end function cuFlushGPUDirectRDMAWrites

        integer(c_int) function cuFuncGetAttribute(pi, attrib, hfunc) &
                bind(C, name="cuFuncGetAttribute")
            import
            integer(c_int), intent(inout) :: pi
            integer(c_int), value :: attrib
            type(c_ptr), value :: hfunc
        end function cuFuncGetAttribute

        integer(c_int) function cuFuncGetModule(hmod, hfunc) &
                bind(C, name="cuFuncGetModule")
            import
            type(c_ptr), intent(out) :: hmod
            type(c_ptr), value :: hfunc
        end function cuFuncGetModule

        integer(c_int) function cuFuncGetName(name, hfunc) &
                bind(C, name="cuFuncGetName")
            import
            type(c_ptr), intent(out) :: name
            type(c_ptr), value :: hfunc
        end function cuFuncGetName

        integer(c_int) function cuFuncGetParamInfo(func, paramIndex, paramOffset, paramSize) &
                bind(C, name="cuFuncGetParamInfo")
            import
            type(c_ptr), value :: func
            integer(c_size_t), value :: paramIndex
            integer(c_size_t), intent(inout) :: paramOffset
            integer(c_size_t), intent(inout) :: paramSize
        end function cuFuncGetParamInfo

        integer(c_int) function cuFuncIsLoaded(state, function) &
                bind(C, name="cuFuncIsLoaded")
            import
            integer(c_int), intent(out) :: state
            type(c_ptr), value :: function
        end function cuFuncIsLoaded

        integer(c_int) function cuFuncLoad(function) &
                bind(C, name="cuFuncLoad")
            import
            type(c_ptr), value :: function
        end function cuFuncLoad

        integer(c_int) function cuFuncSetAttribute(hfunc, attrib, value) &
                bind(C, name="cuFuncSetAttribute")
            import
            type(c_ptr), value :: hfunc
            integer(c_int), value :: attrib
            integer(c_int), value :: value
        end function cuFuncSetAttribute

        integer(c_int) function cuFuncSetBlockShape(hfunc, x, y, z) &
                bind(C, name="cuFuncSetBlockShape")
            import
            type(c_ptr), value :: hfunc
            integer(c_int), value :: x
            integer(c_int), value :: y
            integer(c_int), value :: z
        end function cuFuncSetBlockShape

        integer(c_int) function cuFuncSetCacheConfig(hfunc, config) &
                bind(C, name="cuFuncSetCacheConfig")
            import
            type(c_ptr), value :: hfunc
            integer(c_int), value :: config
        end function cuFuncSetCacheConfig

        integer(c_int) function cuFuncSetSharedMemConfig(hfunc, config) &
                bind(C, name="cuFuncSetSharedMemConfig")
            import
            type(c_ptr), value :: hfunc
            integer(c_int), value :: config
        end function cuFuncSetSharedMemConfig

        integer(c_int) function cuFuncSetSharedSize(hfunc, bytes) &
                bind(C, name="cuFuncSetSharedSize")
            import
            type(c_ptr), value :: hfunc
            integer(c_int), value :: bytes
        end function cuFuncSetSharedSize

        integer(c_int) function cuGetErrorName(error, pStr) &
                bind(C, name="cuGetErrorName")
            import
            integer(c_int), value :: error
            type(c_ptr), intent(out) :: pStr
        end function cuGetErrorName

        integer(c_int) function cuGetErrorString(error, pStr) &
                bind(C, name="cuGetErrorString")
            import
            integer(c_int), value :: error
            type(c_ptr), intent(out) :: pStr
        end function cuGetErrorString

        integer(c_int) function cuGetExportTable(ppExportTable, pExportTableId) &
                bind(C, name="cuGetExportTable")
            import
            type(c_ptr), intent(out) :: ppExportTable
            type(CUuuid_st), intent(in) :: pExportTableId
        end function cuGetExportTable

        integer(c_int) function cuGetProcAddress(symbol, pfn, cudaVersion, flags, symbolStatus) &
                bind(C, name="cuGetProcAddress_v2")   ! header aliases cuGetProcAddress -> cuGetProcAddress_v2
            import
            character(kind=c_char), dimension(*), intent(in) :: symbol
            type(c_ptr), intent(out) :: pfn
            integer(c_int), value :: cudaVersion
            integer(c_int64_t), value :: flags
            integer(c_int), intent(out) :: symbolStatus
        end function cuGetProcAddress

        integer(c_int) function cuGraphAddBatchMemOpNode( &
                phGraphNode, hGraph, dependencies, numDependencies, nodeParams) &
                bind(C, name="cuGraphAddBatchMemOpNode")
            import
            type(c_ptr), intent(out) :: phGraphNode
            type(c_ptr), value :: hGraph
            type(c_ptr), intent(out) :: dependencies
            integer(c_size_t), value :: numDependencies
            type(CUDA_BATCH_MEM_OP_NODE_PARAMS_v1_st), intent(in) :: nodeParams
        end function cuGraphAddBatchMemOpNode

        integer(c_int) function cuGraphAddChildGraphNode( &
                phGraphNode, hGraph, dependencies, numDependencies, childGraph) &
                bind(C, name="cuGraphAddChildGraphNode")
            import
            type(c_ptr), intent(out) :: phGraphNode
            type(c_ptr), value :: hGraph
            type(c_ptr), intent(out) :: dependencies
            integer(c_size_t), value :: numDependencies
            type(c_ptr), value :: childGraph
        end function cuGraphAddChildGraphNode

        integer(c_int) function cuGraphAddDependencies(hGraph, from, to, numDependencies) &
                bind(C, name="cuGraphAddDependencies")
            import
            type(c_ptr), value :: hGraph
            type(c_ptr), intent(out) :: from
            type(c_ptr), intent(out) :: to
            integer(c_size_t), value :: numDependencies
        end function cuGraphAddDependencies

        integer(c_int) function cuGraphAddDependencies_v2(hGraph, from, to, edgeData, numDependencies) &
                bind(C, name="cuGraphAddDependencies_v2")
            import
            type(c_ptr), value :: hGraph
            type(c_ptr), intent(out) :: from
            type(c_ptr), intent(out) :: to
            type(CUgraphEdgeData_st), intent(in) :: edgeData
            integer(c_size_t), value :: numDependencies
        end function cuGraphAddDependencies_v2

        integer(c_int) function cuGraphAddEmptyNode(phGraphNode, hGraph, dependencies, numDependencies) &
                bind(C, name="cuGraphAddEmptyNode")
            import
            type(c_ptr), intent(out) :: phGraphNode
            type(c_ptr), value :: hGraph
            type(c_ptr), intent(out) :: dependencies
            integer(c_size_t), value :: numDependencies
        end function cuGraphAddEmptyNode

        integer(c_int) function cuGraphAddEventRecordNode(phGraphNode, hGraph, dependencies, numDependencies, event) &
                bind(C, name="cuGraphAddEventRecordNode")
            import
            type(c_ptr), intent(out) :: phGraphNode
            type(c_ptr), value :: hGraph
            type(c_ptr), intent(out) :: dependencies
            integer(c_size_t), value :: numDependencies
            type(c_ptr), value :: event
        end function cuGraphAddEventRecordNode

        integer(c_int) function cuGraphAddEventWaitNode(phGraphNode, hGraph, dependencies, numDependencies, event) &
                bind(C, name="cuGraphAddEventWaitNode")
            import
            type(c_ptr), intent(out) :: phGraphNode
            type(c_ptr), value :: hGraph
            type(c_ptr), intent(out) :: dependencies
            integer(c_size_t), value :: numDependencies
            type(c_ptr), value :: event
        end function cuGraphAddEventWaitNode

        integer(c_int) function cuGraphAddExternalSemaphoresSignalNode( &
                phGraphNode, hGraph, dependencies, numDependencies, nodeParams) &
                bind(C, name="cuGraphAddExternalSemaphoresSignalNode")
            import
            type(c_ptr), intent(out) :: phGraphNode
            type(c_ptr), value :: hGraph
            type(c_ptr), intent(out) :: dependencies
            integer(c_size_t), value :: numDependencies
            type(CUDA_EXT_SEM_SIGNAL_NODE_PARAMS_st), intent(in) :: nodeParams
        end function cuGraphAddExternalSemaphoresSignalNode

        integer(c_int) function cuGraphAddExternalSemaphoresWaitNode( &
                phGraphNode, hGraph, dependencies, numDependencies, nodeParams) &
                bind(C, name="cuGraphAddExternalSemaphoresWaitNode")
            import
            type(c_ptr), intent(out) :: phGraphNode
            type(c_ptr), value :: hGraph
            type(c_ptr), intent(out) :: dependencies
            integer(c_size_t), value :: numDependencies
            type(CUDA_EXT_SEM_WAIT_NODE_PARAMS_st), intent(in) :: nodeParams
        end function cuGraphAddExternalSemaphoresWaitNode

        integer(c_int) function cuGraphAddHostNode(phGraphNode, hGraph, dependencies, numDependencies, nodeParams) &
                bind(C, name="cuGraphAddHostNode")
            import
            type(c_ptr), intent(out) :: phGraphNode
            type(c_ptr), value :: hGraph
            type(c_ptr), intent(out) :: dependencies
            integer(c_size_t), value :: numDependencies
            type(CUDA_HOST_NODE_PARAMS_st), intent(in) :: nodeParams
        end function cuGraphAddHostNode

        integer(c_int) function cuGraphAddKernelNode(phGraphNode, hGraph, dependencies, numDependencies, nodeParams) &
                bind(C, name="cuGraphAddKernelNode_v2")   ! header aliases cuGraphAddKernelNode -> cuGraphAddKernelNode_v2
            import
            type(c_ptr), intent(out) :: phGraphNode
            type(c_ptr), value :: hGraph
            type(c_ptr), intent(out) :: dependencies
            integer(c_size_t), value :: numDependencies
            type(CUDA_KERNEL_NODE_PARAMS_v2_st), intent(in) :: nodeParams
        end function cuGraphAddKernelNode

        integer(c_int) function cuGraphAddMemAllocNode(phGraphNode, hGraph, dependencies, numDependencies, nodeParams) &
                bind(C, name="cuGraphAddMemAllocNode")
            import
            type(c_ptr), intent(out) :: phGraphNode
            type(c_ptr), value :: hGraph
            type(c_ptr), intent(out) :: dependencies
            integer(c_size_t), value :: numDependencies
            type(CUDA_MEM_ALLOC_NODE_PARAMS_v1_st), intent(inout) :: nodeParams
        end function cuGraphAddMemAllocNode

        integer(c_int) function cuGraphAddMemFreeNode(phGraphNode, hGraph, dependencies, numDependencies, dptr) &
                bind(C, name="cuGraphAddMemFreeNode")
            import
            type(c_ptr), intent(out) :: phGraphNode
            type(c_ptr), value :: hGraph
            type(c_ptr), intent(out) :: dependencies
            integer(c_size_t), value :: numDependencies
            integer(c_long_long), value :: dptr
        end function cuGraphAddMemFreeNode

        integer(c_int) function cuGraphAddMemcpyNode( &
                phGraphNode, hGraph, dependencies, numDependencies, copyParams, ctx) &
                bind(C, name="cuGraphAddMemcpyNode")
            import
            type(c_ptr), intent(out) :: phGraphNode
            type(c_ptr), value :: hGraph
            type(c_ptr), intent(out) :: dependencies
            integer(c_size_t), value :: numDependencies
            type(CUDA_MEMCPY3D_st), intent(in) :: copyParams
            type(c_ptr), value :: ctx
        end function cuGraphAddMemcpyNode

        integer(c_int) function cuGraphAddMemsetNode( &
                phGraphNode, hGraph, dependencies, numDependencies, memsetParams, ctx) &
                bind(C, name="cuGraphAddMemsetNode")
            import
            type(c_ptr), intent(out) :: phGraphNode
            type(c_ptr), value :: hGraph
            type(c_ptr), intent(out) :: dependencies
            integer(c_size_t), value :: numDependencies
            type(CUDA_MEMSET_NODE_PARAMS_st), intent(in) :: memsetParams
            type(c_ptr), value :: ctx
        end function cuGraphAddMemsetNode

        integer(c_int) function cuGraphAddNode(phGraphNode, hGraph, dependencies, numDependencies, nodeParams) &
                bind(C, name="cuGraphAddNode")
            import
            type(c_ptr), intent(out) :: phGraphNode
            type(c_ptr), value :: hGraph
            type(c_ptr), intent(out) :: dependencies
            integer(c_size_t), value :: numDependencies
            type(CUgraphNodeParams_st), intent(inout) :: nodeParams
        end function cuGraphAddNode

        integer(c_int) function cuGraphAddNode_v2( &
                phGraphNode, hGraph, dependencies, dependencyData, numDependencies, nodeParams) &
                bind(C, name="cuGraphAddNode_v2")
            import
            type(c_ptr), intent(out) :: phGraphNode
            type(c_ptr), value :: hGraph
            type(c_ptr), intent(out) :: dependencies
            type(CUgraphEdgeData_st), intent(in) :: dependencyData
            integer(c_size_t), value :: numDependencies
            type(CUgraphNodeParams_st), intent(inout) :: nodeParams
        end function cuGraphAddNode_v2

        integer(c_int) function cuGraphBatchMemOpNodeGetParams(hNode, nodeParams_out) &
                bind(C, name="cuGraphBatchMemOpNodeGetParams")
            import
            type(c_ptr), value :: hNode
            type(CUDA_BATCH_MEM_OP_NODE_PARAMS_v1_st), intent(inout) :: nodeParams_out
        end function cuGraphBatchMemOpNodeGetParams

        integer(c_int) function cuGraphBatchMemOpNodeSetParams(hNode, nodeParams) &
                bind(C, name="cuGraphBatchMemOpNodeSetParams")
            import
            type(c_ptr), value :: hNode
            type(CUDA_BATCH_MEM_OP_NODE_PARAMS_v1_st), intent(in) :: nodeParams
        end function cuGraphBatchMemOpNodeSetParams

        integer(c_int) function cuGraphChildGraphNodeGetGraph(hNode, phGraph) &
                bind(C, name="cuGraphChildGraphNodeGetGraph")
            import
            type(c_ptr), value :: hNode
            type(c_ptr), intent(out) :: phGraph
        end function cuGraphChildGraphNodeGetGraph

        integer(c_int) function cuGraphClone(phGraphClone, originalGraph) &
                bind(C, name="cuGraphClone")
            import
            type(c_ptr), intent(out) :: phGraphClone
            type(c_ptr), value :: originalGraph
        end function cuGraphClone

        integer(c_int) function cuGraphConditionalHandleCreate(pHandle_out, hGraph, ctx, defaultLaunchValue, flags) &
                bind(C, name="cuGraphConditionalHandleCreate")
            import
            integer(c_int64_t), intent(inout) :: pHandle_out
            type(c_ptr), value :: hGraph
            type(c_ptr), value :: ctx
            integer(c_int), value :: defaultLaunchValue
            integer(c_int), value :: flags
        end function cuGraphConditionalHandleCreate

        integer(c_int) function cuGraphCreate(phGraph, flags) &
                bind(C, name="cuGraphCreate")
            import
            type(c_ptr), intent(out) :: phGraph
            integer(c_int), value :: flags
        end function cuGraphCreate

        integer(c_int) function cuGraphDebugDotPrint(hGraph, path, flags) &
                bind(C, name="cuGraphDebugDotPrint")
            import
            type(c_ptr), value :: hGraph
            character(kind=c_char), dimension(*), intent(in) :: path
            integer(c_int), value :: flags
        end function cuGraphDebugDotPrint

        integer(c_int) function cuGraphDestroy(hGraph) &
                bind(C, name="cuGraphDestroy")
            import
            type(c_ptr), value :: hGraph
        end function cuGraphDestroy

        integer(c_int) function cuGraphDestroyNode(hNode) &
                bind(C, name="cuGraphDestroyNode")
            import
            type(c_ptr), value :: hNode
        end function cuGraphDestroyNode

        integer(c_int) function cuGraphEventRecordNodeGetEvent(hNode, event_out) &
                bind(C, name="cuGraphEventRecordNodeGetEvent")
            import
            type(c_ptr), value :: hNode
            type(c_ptr), intent(out) :: event_out
        end function cuGraphEventRecordNodeGetEvent

        integer(c_int) function cuGraphEventRecordNodeSetEvent(hNode, event) &
                bind(C, name="cuGraphEventRecordNodeSetEvent")
            import
            type(c_ptr), value :: hNode
            type(c_ptr), value :: event
        end function cuGraphEventRecordNodeSetEvent

        integer(c_int) function cuGraphEventWaitNodeGetEvent(hNode, event_out) &
                bind(C, name="cuGraphEventWaitNodeGetEvent")
            import
            type(c_ptr), value :: hNode
            type(c_ptr), intent(out) :: event_out
        end function cuGraphEventWaitNodeGetEvent

        integer(c_int) function cuGraphEventWaitNodeSetEvent(hNode, event) &
                bind(C, name="cuGraphEventWaitNodeSetEvent")
            import
            type(c_ptr), value :: hNode
            type(c_ptr), value :: event
        end function cuGraphEventWaitNodeSetEvent

        integer(c_int) function cuGraphExecBatchMemOpNodeSetParams(hGraphExec, hNode, nodeParams) &
                bind(C, name="cuGraphExecBatchMemOpNodeSetParams")
            import
            type(c_ptr), value :: hGraphExec
            type(c_ptr), value :: hNode
            type(CUDA_BATCH_MEM_OP_NODE_PARAMS_v1_st), intent(in) :: nodeParams
        end function cuGraphExecBatchMemOpNodeSetParams

        integer(c_int) function cuGraphExecChildGraphNodeSetParams(hGraphExec, hNode, childGraph) &
                bind(C, name="cuGraphExecChildGraphNodeSetParams")
            import
            type(c_ptr), value :: hGraphExec
            type(c_ptr), value :: hNode
            type(c_ptr), value :: childGraph
        end function cuGraphExecChildGraphNodeSetParams

        integer(c_int) function cuGraphExecDestroy(hGraphExec) &
                bind(C, name="cuGraphExecDestroy")
            import
            type(c_ptr), value :: hGraphExec
        end function cuGraphExecDestroy

        integer(c_int) function cuGraphExecEventRecordNodeSetEvent(hGraphExec, hNode, event) &
                bind(C, name="cuGraphExecEventRecordNodeSetEvent")
            import
            type(c_ptr), value :: hGraphExec
            type(c_ptr), value :: hNode
            type(c_ptr), value :: event
        end function cuGraphExecEventRecordNodeSetEvent

        integer(c_int) function cuGraphExecEventWaitNodeSetEvent(hGraphExec, hNode, event) &
                bind(C, name="cuGraphExecEventWaitNodeSetEvent")
            import
            type(c_ptr), value :: hGraphExec
            type(c_ptr), value :: hNode
            type(c_ptr), value :: event
        end function cuGraphExecEventWaitNodeSetEvent

        integer(c_int) function cuGraphExecExternalSemaphoresSignalNodeSetParams(hGraphExec, hNode, nodeParams) &
                bind(C, name="cuGraphExecExternalSemaphoresSignalNodeSetParams")
            import
            type(c_ptr), value :: hGraphExec
            type(c_ptr), value :: hNode
            type(CUDA_EXT_SEM_SIGNAL_NODE_PARAMS_st), intent(in) :: nodeParams
        end function cuGraphExecExternalSemaphoresSignalNodeSetParams

        integer(c_int) function cuGraphExecExternalSemaphoresWaitNodeSetParams(hGraphExec, hNode, nodeParams) &
                bind(C, name="cuGraphExecExternalSemaphoresWaitNodeSetParams")
            import
            type(c_ptr), value :: hGraphExec
            type(c_ptr), value :: hNode
            type(CUDA_EXT_SEM_WAIT_NODE_PARAMS_st), intent(in) :: nodeParams
        end function cuGraphExecExternalSemaphoresWaitNodeSetParams

        integer(c_int) function cuGraphExecGetFlags(hGraphExec, flags) &
                bind(C, name="cuGraphExecGetFlags")
            import
            type(c_ptr), value :: hGraphExec
            integer(c_int64_t), intent(inout) :: flags
        end function cuGraphExecGetFlags

        integer(c_int) function cuGraphExecHostNodeSetParams(hGraphExec, hNode, nodeParams) &
                bind(C, name="cuGraphExecHostNodeSetParams")
            import
            type(c_ptr), value :: hGraphExec
            type(c_ptr), value :: hNode
            type(CUDA_HOST_NODE_PARAMS_st), intent(in) :: nodeParams
        end function cuGraphExecHostNodeSetParams

        integer(c_int) function cuGraphExecKernelNodeSetParams(hGraphExec, hNode, nodeParams) &
                bind(C, name="cuGraphExecKernelNodeSetParams_v2")   ! header aliases cuGraphExecKernelNodeSetParams -> cuGraphExecKernelNodeSetParams_v2
            import
            type(c_ptr), value :: hGraphExec
            type(c_ptr), value :: hNode
            type(CUDA_KERNEL_NODE_PARAMS_v2_st), intent(in) :: nodeParams
        end function cuGraphExecKernelNodeSetParams

        integer(c_int) function cuGraphExecMemcpyNodeSetParams(hGraphExec, hNode, copyParams, ctx) &
                bind(C, name="cuGraphExecMemcpyNodeSetParams")
            import
            type(c_ptr), value :: hGraphExec
            type(c_ptr), value :: hNode
            type(CUDA_MEMCPY3D_st), intent(in) :: copyParams
            type(c_ptr), value :: ctx
        end function cuGraphExecMemcpyNodeSetParams

        integer(c_int) function cuGraphExecMemsetNodeSetParams(hGraphExec, hNode, memsetParams, ctx) &
                bind(C, name="cuGraphExecMemsetNodeSetParams")
            import
            type(c_ptr), value :: hGraphExec
            type(c_ptr), value :: hNode
            type(CUDA_MEMSET_NODE_PARAMS_st), intent(in) :: memsetParams
            type(c_ptr), value :: ctx
        end function cuGraphExecMemsetNodeSetParams

        integer(c_int) function cuGraphExecNodeSetParams(hGraphExec, hNode, nodeParams) &
                bind(C, name="cuGraphExecNodeSetParams")
            import
            type(c_ptr), value :: hGraphExec
            type(c_ptr), value :: hNode
            type(CUgraphNodeParams_st), intent(inout) :: nodeParams
        end function cuGraphExecNodeSetParams

        integer(c_int) function cuGraphExecUpdate(hGraphExec, hGraph, resultInfo) &
                bind(C, name="cuGraphExecUpdate_v2")   ! header aliases cuGraphExecUpdate -> cuGraphExecUpdate_v2
            import
            type(c_ptr), value :: hGraphExec
            type(c_ptr), value :: hGraph
            type(CUgraphExecUpdateResultInfo_st), intent(inout) :: resultInfo
        end function cuGraphExecUpdate

        integer(c_int) function cuGraphExternalSemaphoresSignalNodeGetParams(hNode, params_out) &
                bind(C, name="cuGraphExternalSemaphoresSignalNodeGetParams")
            import
            type(c_ptr), value :: hNode
            type(CUDA_EXT_SEM_SIGNAL_NODE_PARAMS_st), intent(inout) :: params_out
        end function cuGraphExternalSemaphoresSignalNodeGetParams

        integer(c_int) function cuGraphExternalSemaphoresSignalNodeSetParams(hNode, nodeParams) &
                bind(C, name="cuGraphExternalSemaphoresSignalNodeSetParams")
            import
            type(c_ptr), value :: hNode
            type(CUDA_EXT_SEM_SIGNAL_NODE_PARAMS_st), intent(in) :: nodeParams
        end function cuGraphExternalSemaphoresSignalNodeSetParams

        integer(c_int) function cuGraphExternalSemaphoresWaitNodeGetParams(hNode, params_out) &
                bind(C, name="cuGraphExternalSemaphoresWaitNodeGetParams")
            import
            type(c_ptr), value :: hNode
            type(CUDA_EXT_SEM_WAIT_NODE_PARAMS_st), intent(inout) :: params_out
        end function cuGraphExternalSemaphoresWaitNodeGetParams

        integer(c_int) function cuGraphExternalSemaphoresWaitNodeSetParams(hNode, nodeParams) &
                bind(C, name="cuGraphExternalSemaphoresWaitNodeSetParams")
            import
            type(c_ptr), value :: hNode
            type(CUDA_EXT_SEM_WAIT_NODE_PARAMS_st), intent(in) :: nodeParams
        end function cuGraphExternalSemaphoresWaitNodeSetParams

        integer(c_int) function cuGraphGetEdges(hGraph, from, to, numEdges) &
                bind(C, name="cuGraphGetEdges")
            import
            type(c_ptr), value :: hGraph
            type(c_ptr), intent(out) :: from
            type(c_ptr), intent(out) :: to
            integer(c_size_t), intent(inout) :: numEdges
        end function cuGraphGetEdges

        integer(c_int) function cuGraphGetEdges_v2(hGraph, from, to, edgeData, numEdges) &
                bind(C, name="cuGraphGetEdges_v2")
            import
            type(c_ptr), value :: hGraph
            type(c_ptr), intent(out) :: from
            type(c_ptr), intent(out) :: to
            type(CUgraphEdgeData_st), intent(inout) :: edgeData
            integer(c_size_t), intent(inout) :: numEdges
        end function cuGraphGetEdges_v2

        integer(c_int) function cuGraphGetNodes(hGraph, nodes, numNodes) &
                bind(C, name="cuGraphGetNodes")
            import
            type(c_ptr), value :: hGraph
            type(c_ptr), intent(out) :: nodes
            integer(c_size_t), intent(inout) :: numNodes
        end function cuGraphGetNodes

        integer(c_int) function cuGraphGetRootNodes(hGraph, rootNodes, numRootNodes) &
                bind(C, name="cuGraphGetRootNodes")
            import
            type(c_ptr), value :: hGraph
            type(c_ptr), intent(out) :: rootNodes
            integer(c_size_t), intent(inout) :: numRootNodes
        end function cuGraphGetRootNodes

        integer(c_int) function cuGraphHostNodeGetParams(hNode, nodeParams) &
                bind(C, name="cuGraphHostNodeGetParams")
            import
            type(c_ptr), value :: hNode
            type(CUDA_HOST_NODE_PARAMS_st), intent(inout) :: nodeParams
        end function cuGraphHostNodeGetParams

        integer(c_int) function cuGraphHostNodeSetParams(hNode, nodeParams) &
                bind(C, name="cuGraphHostNodeSetParams")
            import
            type(c_ptr), value :: hNode
            type(CUDA_HOST_NODE_PARAMS_st), intent(in) :: nodeParams
        end function cuGraphHostNodeSetParams

        integer(c_int) function cuGraphInstantiateWithFlags(phGraphExec, hGraph, flags) &
                bind(C, name="cuGraphInstantiateWithFlags")
            import
            type(c_ptr), intent(out) :: phGraphExec
            type(c_ptr), value :: hGraph
            integer(c_long_long), value :: flags
        end function cuGraphInstantiateWithFlags

        integer(c_int) function cuGraphInstantiateWithParams(phGraphExec, hGraph, instantiateParams) &
                bind(C, name="cuGraphInstantiateWithParams")
            import
            type(c_ptr), intent(out) :: phGraphExec
            type(c_ptr), value :: hGraph
            type(CUDA_GRAPH_INSTANTIATE_PARAMS_st), intent(inout) :: instantiateParams
        end function cuGraphInstantiateWithParams

        integer(c_int) function cuGraphKernelNodeCopyAttributes(dst, src) &
                bind(C, name="cuGraphKernelNodeCopyAttributes")
            import
            type(c_ptr), value :: dst
            type(c_ptr), value :: src
        end function cuGraphKernelNodeCopyAttributes

        integer(c_int) function cuGraphKernelNodeGetAttribute(hNode, attr, value_out) &
                bind(C, name="cuGraphKernelNodeGetAttribute")
            import
            type(c_ptr), value :: hNode
            integer(c_int), value :: attr
            type(CUlaunchAttributeValue_union), intent(inout) :: value_out
        end function cuGraphKernelNodeGetAttribute

        integer(c_int) function cuGraphKernelNodeGetParams(hNode, nodeParams) &
                bind(C, name="cuGraphKernelNodeGetParams_v2")   ! header aliases cuGraphKernelNodeGetParams -> cuGraphKernelNodeGetParams_v2
            import
            type(c_ptr), value :: hNode
            type(CUDA_KERNEL_NODE_PARAMS_v2_st), intent(inout) :: nodeParams
        end function cuGraphKernelNodeGetParams

        integer(c_int) function cuGraphKernelNodeSetAttribute(hNode, attr, value) &
                bind(C, name="cuGraphKernelNodeSetAttribute")
            import
            type(c_ptr), value :: hNode
            integer(c_int), value :: attr
            type(CUlaunchAttributeValue_union), intent(in) :: value
        end function cuGraphKernelNodeSetAttribute

        integer(c_int) function cuGraphKernelNodeSetParams(hNode, nodeParams) &
                bind(C, name="cuGraphKernelNodeSetParams_v2")   ! header aliases cuGraphKernelNodeSetParams -> cuGraphKernelNodeSetParams_v2
            import
            type(c_ptr), value :: hNode
            type(CUDA_KERNEL_NODE_PARAMS_v2_st), intent(in) :: nodeParams
        end function cuGraphKernelNodeSetParams

        integer(c_int) function cuGraphLaunch(hGraphExec, hStream) &
                bind(C, name="cuGraphLaunch")
            import
            type(c_ptr), value :: hGraphExec
            type(c_ptr), value :: hStream
        end function cuGraphLaunch

        integer(c_int) function cuGraphMemAllocNodeGetParams(hNode, params_out) &
                bind(C, name="cuGraphMemAllocNodeGetParams")
            import
            type(c_ptr), value :: hNode
            type(CUDA_MEM_ALLOC_NODE_PARAMS_v1_st), intent(inout) :: params_out
        end function cuGraphMemAllocNodeGetParams

        integer(c_int) function cuGraphMemFreeNodeGetParams(hNode, dptr_out) &
                bind(C, name="cuGraphMemFreeNodeGetParams")
            import
            type(c_ptr), value :: hNode
            integer(c_long_long), intent(inout) :: dptr_out
        end function cuGraphMemFreeNodeGetParams

        integer(c_int) function cuGraphMemcpyNodeGetParams(hNode, nodeParams) &
                bind(C, name="cuGraphMemcpyNodeGetParams")
            import
            type(c_ptr), value :: hNode
            type(CUDA_MEMCPY3D_st), intent(inout) :: nodeParams
        end function cuGraphMemcpyNodeGetParams

        integer(c_int) function cuGraphMemcpyNodeSetParams(hNode, nodeParams) &
                bind(C, name="cuGraphMemcpyNodeSetParams")
            import
            type(c_ptr), value :: hNode
            type(CUDA_MEMCPY3D_st), intent(in) :: nodeParams
        end function cuGraphMemcpyNodeSetParams

        integer(c_int) function cuGraphMemsetNodeGetParams(hNode, nodeParams) &
                bind(C, name="cuGraphMemsetNodeGetParams")
            import
            type(c_ptr), value :: hNode
            type(CUDA_MEMSET_NODE_PARAMS_st), intent(inout) :: nodeParams
        end function cuGraphMemsetNodeGetParams

        integer(c_int) function cuGraphMemsetNodeSetParams(hNode, nodeParams) &
                bind(C, name="cuGraphMemsetNodeSetParams")
            import
            type(c_ptr), value :: hNode
            type(CUDA_MEMSET_NODE_PARAMS_st), intent(in) :: nodeParams
        end function cuGraphMemsetNodeSetParams

        integer(c_int) function cuGraphNodeFindInClone(phNode, hOriginalNode, hClonedGraph) &
                bind(C, name="cuGraphNodeFindInClone")
            import
            type(c_ptr), intent(out) :: phNode
            type(c_ptr), value :: hOriginalNode
            type(c_ptr), value :: hClonedGraph
        end function cuGraphNodeFindInClone

        integer(c_int) function cuGraphNodeGetDependencies(hNode, dependencies, numDependencies) &
                bind(C, name="cuGraphNodeGetDependencies")
            import
            type(c_ptr), value :: hNode
            type(c_ptr), intent(out) :: dependencies
            integer(c_size_t), intent(inout) :: numDependencies
        end function cuGraphNodeGetDependencies

        integer(c_int) function cuGraphNodeGetDependencies_v2(hNode, dependencies, edgeData, numDependencies) &
                bind(C, name="cuGraphNodeGetDependencies_v2")
            import
            type(c_ptr), value :: hNode
            type(c_ptr), intent(out) :: dependencies
            type(CUgraphEdgeData_st), intent(inout) :: edgeData
            integer(c_size_t), intent(inout) :: numDependencies
        end function cuGraphNodeGetDependencies_v2

        integer(c_int) function cuGraphNodeGetDependentNodes(hNode, dependentNodes, numDependentNodes) &
                bind(C, name="cuGraphNodeGetDependentNodes")
            import
            type(c_ptr), value :: hNode
            type(c_ptr), intent(out) :: dependentNodes
            integer(c_size_t), intent(inout) :: numDependentNodes
        end function cuGraphNodeGetDependentNodes

        integer(c_int) function cuGraphNodeGetDependentNodes_v2(hNode, dependentNodes, edgeData, numDependentNodes) &
                bind(C, name="cuGraphNodeGetDependentNodes_v2")
            import
            type(c_ptr), value :: hNode
            type(c_ptr), intent(out) :: dependentNodes
            type(CUgraphEdgeData_st), intent(inout) :: edgeData
            integer(c_size_t), intent(inout) :: numDependentNodes
        end function cuGraphNodeGetDependentNodes_v2

        integer(c_int) function cuGraphNodeGetEnabled(hGraphExec, hNode, isEnabled) &
                bind(C, name="cuGraphNodeGetEnabled")
            import
            type(c_ptr), value :: hGraphExec
            type(c_ptr), value :: hNode
            integer(c_int), intent(inout) :: isEnabled
        end function cuGraphNodeGetEnabled

        integer(c_int) function cuGraphNodeGetType(hNode, type) &
                bind(C, name="cuGraphNodeGetType")
            import
            type(c_ptr), value :: hNode
            integer(c_int), intent(out) :: type
        end function cuGraphNodeGetType

        integer(c_int) function cuGraphNodeSetEnabled(hGraphExec, hNode, isEnabled) &
                bind(C, name="cuGraphNodeSetEnabled")
            import
            type(c_ptr), value :: hGraphExec
            type(c_ptr), value :: hNode
            integer(c_int), value :: isEnabled
        end function cuGraphNodeSetEnabled

        integer(c_int) function cuGraphNodeSetParams(hNode, nodeParams) &
                bind(C, name="cuGraphNodeSetParams")
            import
            type(c_ptr), value :: hNode
            type(CUgraphNodeParams_st), intent(inout) :: nodeParams
        end function cuGraphNodeSetParams

        integer(c_int) function cuGraphReleaseUserObject(graph, object, count) &
                bind(C, name="cuGraphReleaseUserObject")
            import
            type(c_ptr), value :: graph
            type(c_ptr), value :: object
            integer(c_int), value :: count
        end function cuGraphReleaseUserObject

        integer(c_int) function cuGraphRemoveDependencies(hGraph, from, to, numDependencies) &
                bind(C, name="cuGraphRemoveDependencies")
            import
            type(c_ptr), value :: hGraph
            type(c_ptr), intent(out) :: from
            type(c_ptr), intent(out) :: to
            integer(c_size_t), value :: numDependencies
        end function cuGraphRemoveDependencies

        integer(c_int) function cuGraphRemoveDependencies_v2(hGraph, from, to, edgeData, numDependencies) &
                bind(C, name="cuGraphRemoveDependencies_v2")
            import
            type(c_ptr), value :: hGraph
            type(c_ptr), intent(out) :: from
            type(c_ptr), intent(out) :: to
            type(CUgraphEdgeData_st), intent(in) :: edgeData
            integer(c_size_t), value :: numDependencies
        end function cuGraphRemoveDependencies_v2

        integer(c_int) function cuGraphRetainUserObject(graph, object, count, flags) &
                bind(C, name="cuGraphRetainUserObject")
            import
            type(c_ptr), value :: graph
            type(c_ptr), value :: object
            integer(c_int), value :: count
            integer(c_int), value :: flags
        end function cuGraphRetainUserObject

        integer(c_int) function cuGraphUpload(hGraphExec, hStream) &
                bind(C, name="cuGraphUpload")
            import
            type(c_ptr), value :: hGraphExec
            type(c_ptr), value :: hStream
        end function cuGraphUpload

        integer(c_int) function cuGraphicsMapResources(count, resources, hStream) &
                bind(C, name="cuGraphicsMapResources")
            import
            integer(c_int), value :: count
            type(c_ptr), intent(out) :: resources
            type(c_ptr), value :: hStream
        end function cuGraphicsMapResources

        integer(c_int) function cuGraphicsResourceGetMappedMipmappedArray(pMipmappedArray, resource) &
                bind(C, name="cuGraphicsResourceGetMappedMipmappedArray")
            import
            type(c_ptr), intent(out) :: pMipmappedArray
            type(c_ptr), value :: resource
        end function cuGraphicsResourceGetMappedMipmappedArray

        integer(c_int) function cuGraphicsResourceGetMappedPointer(pDevPtr, pSize, resource) &
                bind(C, name="cuGraphicsResourceGetMappedPointer_v2")   ! header aliases cuGraphicsResourceGetMappedPointer -> cuGraphicsResourceGetMappedPointer_v2
            import
            integer(c_long_long), intent(inout) :: pDevPtr
            integer(c_size_t), intent(inout) :: pSize
            type(c_ptr), value :: resource
        end function cuGraphicsResourceGetMappedPointer

        integer(c_int) function cuGraphicsResourceSetMapFlags(resource, flags) &
                bind(C, name="cuGraphicsResourceSetMapFlags_v2")   ! header aliases cuGraphicsResourceSetMapFlags -> cuGraphicsResourceSetMapFlags_v2
            import
            type(c_ptr), value :: resource
            integer(c_int), value :: flags
        end function cuGraphicsResourceSetMapFlags

        integer(c_int) function cuGraphicsSubResourceGetMappedArray(pArray, resource, arrayIndex, mipLevel) &
                bind(C, name="cuGraphicsSubResourceGetMappedArray")
            import
            type(c_ptr), intent(out) :: pArray
            type(c_ptr), value :: resource
            integer(c_int), value :: arrayIndex
            integer(c_int), value :: mipLevel
        end function cuGraphicsSubResourceGetMappedArray

        integer(c_int) function cuGraphicsUnmapResources(count, resources, hStream) &
                bind(C, name="cuGraphicsUnmapResources")
            import
            integer(c_int), value :: count
            type(c_ptr), intent(out) :: resources
            type(c_ptr), value :: hStream
        end function cuGraphicsUnmapResources

        integer(c_int) function cuGraphicsUnregisterResource(resource) &
                bind(C, name="cuGraphicsUnregisterResource")
            import
            type(c_ptr), value :: resource
        end function cuGraphicsUnregisterResource

        integer(c_int) function cuGreenCtxCreate(phCtx, desc, dev, flags) &
                bind(C, name="cuGreenCtxCreate")
            import
            type(c_ptr), intent(out) :: phCtx
            type(c_ptr), value :: desc
            integer(c_int), value :: dev
            integer(c_int), value :: flags
        end function cuGreenCtxCreate

        integer(c_int) function cuGreenCtxDestroy(hCtx) &
                bind(C, name="cuGreenCtxDestroy")
            import
            type(c_ptr), value :: hCtx
        end function cuGreenCtxDestroy

        integer(c_int) function cuGreenCtxGetDevResource(hCtx, resource, type) &
                bind(C, name="cuGreenCtxGetDevResource")
            import
            type(c_ptr), value :: hCtx
            type(CUdevResource_st), intent(inout) :: resource
            integer(c_int), value :: type
        end function cuGreenCtxGetDevResource

        integer(c_int) function cuGreenCtxRecordEvent(hCtx, hEvent) &
                bind(C, name="cuGreenCtxRecordEvent")
            import
            type(c_ptr), value :: hCtx
            type(c_ptr), value :: hEvent
        end function cuGreenCtxRecordEvent

        integer(c_int) function cuGreenCtxStreamCreate(phStream, greenCtx, flags, priority) &
                bind(C, name="cuGreenCtxStreamCreate")
            import
            type(c_ptr), intent(out) :: phStream
            type(c_ptr), value :: greenCtx
            integer(c_int), value :: flags
            integer(c_int), value :: priority
        end function cuGreenCtxStreamCreate

        integer(c_int) function cuGreenCtxWaitEvent(hCtx, hEvent) &
                bind(C, name="cuGreenCtxWaitEvent")
            import
            type(c_ptr), value :: hCtx
            type(c_ptr), value :: hEvent
        end function cuGreenCtxWaitEvent

        integer(c_int) function cuImportExternalMemory(extMem_out, memHandleDesc) &
                bind(C, name="cuImportExternalMemory")
            import
            type(c_ptr), intent(out) :: extMem_out
            type(CUDA_EXTERNAL_MEMORY_HANDLE_DESC_st), intent(in) :: memHandleDesc
        end function cuImportExternalMemory

        integer(c_int) function cuImportExternalSemaphore(extSem_out, semHandleDesc) &
                bind(C, name="cuImportExternalSemaphore")
            import
            type(c_ptr), intent(out) :: extSem_out
            type(CUDA_EXTERNAL_SEMAPHORE_HANDLE_DESC_st), intent(in) :: semHandleDesc
        end function cuImportExternalSemaphore

        integer(c_int) function cuInit(Flags) &
                bind(C, name="cuInit")
            import
            integer(c_int), value :: Flags
        end function cuInit

        integer(c_int) function cuIpcCloseMemHandle(dptr) &
                bind(C, name="cuIpcCloseMemHandle")
            import
            integer(c_long_long), value :: dptr
        end function cuIpcCloseMemHandle

        integer(c_int) function cuIpcGetEventHandle(pHandle, event) &
                bind(C, name="cuIpcGetEventHandle")
            import
            type(CUipcEventHandle_st), intent(inout) :: pHandle
            type(c_ptr), value :: event
        end function cuIpcGetEventHandle

        integer(c_int) function cuIpcGetMemHandle(pHandle, dptr) &
                bind(C, name="cuIpcGetMemHandle")
            import
            type(CUipcMemHandle_st), intent(inout) :: pHandle
            integer(c_long_long), value :: dptr
        end function cuIpcGetMemHandle

        integer(c_int) function cuIpcOpenEventHandle(phEvent, handle) &
                bind(C, name="cuIpcOpenEventHandle")
            import
            type(c_ptr), intent(out) :: phEvent
            type(CUipcEventHandle_st), value :: handle
        end function cuIpcOpenEventHandle

        integer(c_int) function cuIpcOpenMemHandle(pdptr, handle, Flags) &
                bind(C, name="cuIpcOpenMemHandle_v2")   ! header aliases cuIpcOpenMemHandle -> cuIpcOpenMemHandle_v2
            import
            integer(c_long_long), intent(inout) :: pdptr
            type(CUipcMemHandle_st), value :: handle
            integer(c_int), value :: Flags
        end function cuIpcOpenMemHandle

        integer(c_int) function cuKernelGetAttribute(pi, attrib, kernel, dev) &
                bind(C, name="cuKernelGetAttribute")
            import
            integer(c_int), intent(inout) :: pi
            integer(c_int), value :: attrib
            type(c_ptr), value :: kernel
            integer(c_int), value :: dev
        end function cuKernelGetAttribute

        integer(c_int) function cuKernelGetFunction(pFunc, kernel) &
                bind(C, name="cuKernelGetFunction")
            import
            type(c_ptr), intent(out) :: pFunc
            type(c_ptr), value :: kernel
        end function cuKernelGetFunction

        integer(c_int) function cuKernelGetLibrary(pLib, kernel) &
                bind(C, name="cuKernelGetLibrary")
            import
            type(c_ptr), intent(out) :: pLib
            type(c_ptr), value :: kernel
        end function cuKernelGetLibrary

        integer(c_int) function cuKernelGetName(name, hfunc) &
                bind(C, name="cuKernelGetName")
            import
            type(c_ptr), intent(out) :: name
            type(c_ptr), value :: hfunc
        end function cuKernelGetName

        integer(c_int) function cuKernelGetParamInfo(kernel, paramIndex, paramOffset, paramSize) &
                bind(C, name="cuKernelGetParamInfo")
            import
            type(c_ptr), value :: kernel
            integer(c_size_t), value :: paramIndex
            integer(c_size_t), intent(inout) :: paramOffset
            integer(c_size_t), intent(inout) :: paramSize
        end function cuKernelGetParamInfo

        integer(c_int) function cuKernelSetAttribute(attrib, val, kernel, dev) &
                bind(C, name="cuKernelSetAttribute")
            import
            integer(c_int), value :: attrib
            integer(c_int), value :: val
            type(c_ptr), value :: kernel
            integer(c_int), value :: dev
        end function cuKernelSetAttribute

        integer(c_int) function cuKernelSetCacheConfig(kernel, config, dev) &
                bind(C, name="cuKernelSetCacheConfig")
            import
            type(c_ptr), value :: kernel
            integer(c_int), value :: config
            integer(c_int), value :: dev
        end function cuKernelSetCacheConfig

        integer(c_int) function cuLaunch(f) &
                bind(C, name="cuLaunch")
            import
            type(c_ptr), value :: f
        end function cuLaunch

        integer(c_int) function cuLaunchCooperativeKernel( &
                f, gridDimX, gridDimY, gridDimZ, blockDimX, blockDimY, blockDimZ, sharedMemBytes, hStream, &
                kernelParams) &
                bind(C, name="cuLaunchCooperativeKernel")
            import
            type(c_ptr), value :: f
            integer(c_int), value :: gridDimX
            integer(c_int), value :: gridDimY
            integer(c_int), value :: gridDimZ
            integer(c_int), value :: blockDimX
            integer(c_int), value :: blockDimY
            integer(c_int), value :: blockDimZ
            integer(c_int), value :: sharedMemBytes
            type(c_ptr), value :: hStream
            type(c_ptr), dimension(*), intent(in) :: kernelParams
        end function cuLaunchCooperativeKernel

        integer(c_int) function cuLaunchCooperativeKernelMultiDevice(launchParamsList, numDevices, flags) &
                bind(C, name="cuLaunchCooperativeKernelMultiDevice")
            import
            type(CUDA_LAUNCH_PARAMS_st), intent(inout) :: launchParamsList
            integer(c_int), value :: numDevices
            integer(c_int), value :: flags
        end function cuLaunchCooperativeKernelMultiDevice

        integer(c_int) function cuLaunchGrid(f, grid_width, grid_height) &
                bind(C, name="cuLaunchGrid")
            import
            type(c_ptr), value :: f
            integer(c_int), value :: grid_width
            integer(c_int), value :: grid_height
        end function cuLaunchGrid

        integer(c_int) function cuLaunchGridAsync(f, grid_width, grid_height, hStream) &
                bind(C, name="cuLaunchGridAsync")
            import
            type(c_ptr), value :: f
            integer(c_int), value :: grid_width
            integer(c_int), value :: grid_height
            type(c_ptr), value :: hStream
        end function cuLaunchGridAsync

        integer(c_int) function cuLaunchHostFunc(hStream, fn, userData) &
                bind(C, name="cuLaunchHostFunc")
            import
            type(c_ptr), value :: hStream
            type(c_funptr), value :: fn
            type(c_ptr), value :: userData
        end function cuLaunchHostFunc

        integer(c_int) function cuLaunchKernel( &
                f, gridDimX, gridDimY, gridDimZ, blockDimX, blockDimY, blockDimZ, sharedMemBytes, hStream, &
                kernelParams, extra) &
                bind(C, name="cuLaunchKernel")
            import
            type(c_ptr), value :: f
            integer(c_int), value :: gridDimX
            integer(c_int), value :: gridDimY
            integer(c_int), value :: gridDimZ
            integer(c_int), value :: blockDimX
            integer(c_int), value :: blockDimY
            integer(c_int), value :: blockDimZ
            integer(c_int), value :: sharedMemBytes
            type(c_ptr), value :: hStream
            type(c_ptr), dimension(*), intent(in) :: kernelParams
            type(c_ptr), dimension(*), intent(in) :: extra
        end function cuLaunchKernel

        integer(c_int) function cuLaunchKernelEx(config, f, kernelParams, extra) &
                bind(C, name="cuLaunchKernelEx")
            import
            type(CUlaunchConfig_st), intent(in) :: config
            type(c_ptr), value :: f
            type(c_ptr), dimension(*), intent(in) :: kernelParams
            type(c_ptr), dimension(*), intent(in) :: extra
        end function cuLaunchKernelEx

        integer(c_int) function cuLibraryEnumerateKernels(kernels, numKernels, lib) &
                bind(C, name="cuLibraryEnumerateKernels")
            import
            type(c_ptr), intent(out) :: kernels
            integer(c_int), value :: numKernels
            type(c_ptr), value :: lib
        end function cuLibraryEnumerateKernels

        integer(c_int) function cuLibraryGetGlobal(dptr, bytes, library, name) &
                bind(C, name="cuLibraryGetGlobal")
            import
            integer(c_long_long), intent(inout) :: dptr
            integer(c_size_t), intent(inout) :: bytes
            type(c_ptr), value :: library
            character(kind=c_char), dimension(*), intent(in) :: name
        end function cuLibraryGetGlobal

        integer(c_int) function cuLibraryGetKernel(pKernel, library, name) &
                bind(C, name="cuLibraryGetKernel")
            import
            type(c_ptr), intent(out) :: pKernel
            type(c_ptr), value :: library
            character(kind=c_char), dimension(*), intent(in) :: name
        end function cuLibraryGetKernel

        integer(c_int) function cuLibraryGetKernelCount(count, lib) &
                bind(C, name="cuLibraryGetKernelCount")
            import
            integer(c_int), intent(inout) :: count
            type(c_ptr), value :: lib
        end function cuLibraryGetKernelCount

        integer(c_int) function cuLibraryGetManaged(dptr, bytes, library, name) &
                bind(C, name="cuLibraryGetManaged")
            import
            integer(c_long_long), intent(inout) :: dptr
            integer(c_size_t), intent(inout) :: bytes
            type(c_ptr), value :: library
            character(kind=c_char), dimension(*), intent(in) :: name
        end function cuLibraryGetManaged

        integer(c_int) function cuLibraryGetModule(pMod, library) &
                bind(C, name="cuLibraryGetModule")
            import
            type(c_ptr), intent(out) :: pMod
            type(c_ptr), value :: library
        end function cuLibraryGetModule

        integer(c_int) function cuLibraryGetUnifiedFunction(fptr, library, symbol) &
                bind(C, name="cuLibraryGetUnifiedFunction")
            import
            type(c_ptr), intent(out) :: fptr
            type(c_ptr), value :: library
            character(kind=c_char), dimension(*), intent(in) :: symbol
        end function cuLibraryGetUnifiedFunction

        integer(c_int) function cuLibraryLoadData( &
                library, code, jitOptions, jitOptionsValues, numJitOptions, libraryOptions, libraryOptionValues, &
                numLibraryOptions) &
                bind(C, name="cuLibraryLoadData")
            import
            type(c_ptr), intent(out) :: library
            type(c_ptr), value :: code
            integer(c_int), intent(out) :: jitOptions
            type(c_ptr), intent(out) :: jitOptionsValues
            integer(c_int), value :: numJitOptions
            integer(c_int), intent(out) :: libraryOptions
            type(c_ptr), intent(out) :: libraryOptionValues
            integer(c_int), value :: numLibraryOptions
        end function cuLibraryLoadData

        integer(c_int) function cuLibraryLoadFromFile( &
                library, fileName, jitOptions, jitOptionsValues, numJitOptions, libraryOptions, libraryOptionValues, &
                numLibraryOptions) &
                bind(C, name="cuLibraryLoadFromFile")
            import
            type(c_ptr), intent(out) :: library
            character(kind=c_char), dimension(*), intent(in) :: fileName
            integer(c_int), intent(out) :: jitOptions
            type(c_ptr), intent(out) :: jitOptionsValues
            integer(c_int), value :: numJitOptions
            integer(c_int), intent(out) :: libraryOptions
            type(c_ptr), intent(out) :: libraryOptionValues
            integer(c_int), value :: numLibraryOptions
        end function cuLibraryLoadFromFile

        integer(c_int) function cuLibraryUnload(library) &
                bind(C, name="cuLibraryUnload")
            import
            type(c_ptr), value :: library
        end function cuLibraryUnload

        integer(c_int) function cuLinkAddData(state, type, data, size, name, numOptions, options, optionValues) &
                bind(C, name="cuLinkAddData_v2")   ! header aliases cuLinkAddData -> cuLinkAddData_v2
            import
            type(c_ptr), value :: state
            integer(c_int), value :: type
            type(c_ptr), value :: data
            integer(c_size_t), value :: size
            character(kind=c_char), dimension(*), intent(in) :: name
            integer(c_int), value :: numOptions
            integer(c_int), intent(out) :: options
            type(c_ptr), intent(out) :: optionValues
        end function cuLinkAddData

        integer(c_int) function cuLinkAddFile(state, type, path, numOptions, options, optionValues) &
                bind(C, name="cuLinkAddFile_v2")   ! header aliases cuLinkAddFile -> cuLinkAddFile_v2
            import
            type(c_ptr), value :: state
            integer(c_int), value :: type
            character(kind=c_char), dimension(*), intent(in) :: path
            integer(c_int), value :: numOptions
            integer(c_int), intent(out) :: options
            type(c_ptr), intent(out) :: optionValues
        end function cuLinkAddFile

        integer(c_int) function cuLinkComplete(state, cubinOut, sizeOut) &
                bind(C, name="cuLinkComplete")
            import
            type(c_ptr), value :: state
            type(c_ptr), intent(out) :: cubinOut
            integer(c_size_t), intent(inout) :: sizeOut
        end function cuLinkComplete

        integer(c_int) function cuLinkCreate(numOptions, options, optionValues, stateOut) &
                bind(C, name="cuLinkCreate_v2")   ! header aliases cuLinkCreate -> cuLinkCreate_v2
            import
            integer(c_int), value :: numOptions
            integer(c_int), intent(out) :: options
            type(c_ptr), intent(out) :: optionValues
            type(c_ptr), intent(out) :: stateOut
        end function cuLinkCreate

        integer(c_int) function cuLinkDestroy(state) &
                bind(C, name="cuLinkDestroy")
            import
            type(c_ptr), value :: state
        end function cuLinkDestroy

        integer(c_int) function cuLogsCurrent(iterator_out, flags) &
                bind(C, name="cuLogsCurrent")
            import
            integer(c_int), intent(inout) :: iterator_out
            integer(c_int), value :: flags
        end function cuLogsCurrent

        integer(c_int) function cuLogsDumpToFile(iterator, pathToFile, flags) &
                bind(C, name="cuLogsDumpToFile")
            import
            integer(c_int), intent(inout) :: iterator
            character(kind=c_char), dimension(*), intent(in) :: pathToFile
            integer(c_int), value :: flags
        end function cuLogsDumpToFile

        integer(c_int) function cuLogsDumpToMemory(iterator, buffer, size, flags) &
                bind(C, name="cuLogsDumpToMemory")
            import
            integer(c_int), intent(inout) :: iterator
            character(kind=c_char), dimension(*), intent(in) :: buffer
            integer(c_size_t), intent(inout) :: size
            integer(c_int), value :: flags
        end function cuLogsDumpToMemory

        integer(c_int) function cuLogsRegisterCallback(callbackFunc, userData, callback_out) &
                bind(C, name="cuLogsRegisterCallback")
            import
            type(c_funptr), value :: callbackFunc
            type(c_ptr), value :: userData
            type(c_ptr), intent(out) :: callback_out
        end function cuLogsRegisterCallback

        integer(c_int) function cuLogsUnregisterCallback(callback) &
                bind(C, name="cuLogsUnregisterCallback")
            import
            type(c_ptr), value :: callback
        end function cuLogsUnregisterCallback

        integer(c_int) function cuMemAddressFree(ptr, size) &
                bind(C, name="cuMemAddressFree")
            import
            integer(c_long_long), value :: ptr
            integer(c_size_t), value :: size
        end function cuMemAddressFree

        integer(c_int) function cuMemAddressReserve(ptr, size, alignment, addr, flags) &
                bind(C, name="cuMemAddressReserve")
            import
            integer(c_long_long), intent(inout) :: ptr
            integer(c_size_t), value :: size
            integer(c_size_t), value :: alignment
            integer(c_long_long), value :: addr
            integer(c_long_long), value :: flags
        end function cuMemAddressReserve

        integer(c_int) function cuMemAdvise(devPtr, count, advice, device) &
                bind(C, name="cuMemAdvise")
            import
            integer(c_long_long), value :: devPtr
            integer(c_size_t), value :: count
            integer(c_int), value :: advice
            integer(c_int), value :: device
        end function cuMemAdvise

        integer(c_int) function cuMemAdvise_v2(devPtr, count, advice, location) &
                bind(C, name="cuMemAdvise_v2")
            import
            integer(c_long_long), value :: devPtr
            integer(c_size_t), value :: count
            integer(c_int), value :: advice
            type(CUmemLocation_st), value :: location
        end function cuMemAdvise_v2

        integer(c_int) function cuMemAllocAsync(dptr, bytesize, hStream) &
                bind(C, name="cuMemAllocAsync")
            import
            integer(c_long_long), intent(inout) :: dptr
            integer(c_size_t), value :: bytesize
            type(c_ptr), value :: hStream
        end function cuMemAllocAsync

        integer(c_int) function cuMemAllocFromPoolAsync(dptr, bytesize, pool, hStream) &
                bind(C, name="cuMemAllocFromPoolAsync")
            import
            integer(c_long_long), intent(inout) :: dptr
            integer(c_size_t), value :: bytesize
            type(c_ptr), value :: pool
            type(c_ptr), value :: hStream
        end function cuMemAllocFromPoolAsync

        integer(c_int) function cuMemAllocHost(pp, bytesize) &
                bind(C, name="cuMemAllocHost_v2")   ! header aliases cuMemAllocHost -> cuMemAllocHost_v2
            import
            type(c_ptr), intent(out) :: pp
            integer(c_size_t), value :: bytesize
        end function cuMemAllocHost

        integer(c_int) function cuMemAllocManaged(dptr, bytesize, flags) &
                bind(C, name="cuMemAllocManaged")
            import
            integer(c_long_long), intent(inout) :: dptr
            integer(c_size_t), value :: bytesize
            integer(c_int), value :: flags
        end function cuMemAllocManaged

        integer(c_int) function cuMemAllocPitch(dptr, pPitch, WidthInBytes, Height, ElementSizeBytes) &
                bind(C, name="cuMemAllocPitch_v2")   ! header aliases cuMemAllocPitch -> cuMemAllocPitch_v2
            import
            integer(c_long_long), intent(inout) :: dptr
            integer(c_size_t), intent(inout) :: pPitch
            integer(c_size_t), value :: WidthInBytes
            integer(c_size_t), value :: Height
            integer(c_int), value :: ElementSizeBytes
        end function cuMemAllocPitch

        integer(c_int) function cuMemAlloc(dptr, bytesize) &
                bind(C, name="cuMemAlloc_v2")   ! header aliases cuMemAlloc -> cuMemAlloc_v2
            import
            integer(c_long_long), intent(inout) :: dptr
            integer(c_size_t), value :: bytesize
        end function cuMemAlloc

        integer(c_int) function cuMemBatchDecompressAsync(paramsArray, count, flags, errorIndex, stream) &
                bind(C, name="cuMemBatchDecompressAsync")
            import
            type(CUmemDecompressParams_st), intent(inout) :: paramsArray
            integer(c_size_t), value :: count
            integer(c_int), value :: flags
            integer(c_size_t), intent(inout) :: errorIndex
            type(c_ptr), value :: stream
        end function cuMemBatchDecompressAsync

        integer(c_int) function cuMemCreate(handle, size, prop, flags) &
                bind(C, name="cuMemCreate")
            import
            integer(c_long_long), intent(inout) :: handle
            integer(c_size_t), value :: size
            type(CUmemAllocationProp_st), intent(in) :: prop
            integer(c_long_long), value :: flags
        end function cuMemCreate

        integer(c_int) function cuMemExportToShareableHandle(shareableHandle, handle, handleType, flags) &
                bind(C, name="cuMemExportToShareableHandle")
            import
            type(c_ptr), value :: shareableHandle
            integer(c_long_long), value :: handle
            integer(c_int), value :: handleType
            integer(c_long_long), value :: flags
        end function cuMemExportToShareableHandle

        integer(c_int) function cuMemFreeAsync(dptr, hStream) &
                bind(C, name="cuMemFreeAsync")
            import
            integer(c_long_long), value :: dptr
            type(c_ptr), value :: hStream
        end function cuMemFreeAsync

        integer(c_int) function cuMemFreeHost(p) &
                bind(C, name="cuMemFreeHost")
            import
            type(c_ptr), value :: p
        end function cuMemFreeHost

        integer(c_int) function cuMemFree(dptr) &
                bind(C, name="cuMemFree_v2")   ! header aliases cuMemFree -> cuMemFree_v2
            import
            integer(c_long_long), value :: dptr
        end function cuMemFree

        integer(c_int) function cuMemGetAccess(flags, location, ptr) &
                bind(C, name="cuMemGetAccess")
            import
            integer(c_long_long), intent(inout) :: flags
            type(CUmemLocation_st), intent(in) :: location
            integer(c_long_long), value :: ptr
        end function cuMemGetAccess

        integer(c_int) function cuMemGetAddressRange(pbase, psize, dptr) &
                bind(C, name="cuMemGetAddressRange_v2")   ! header aliases cuMemGetAddressRange -> cuMemGetAddressRange_v2
            import
            integer(c_long_long), intent(inout) :: pbase
            integer(c_size_t), intent(inout) :: psize
            integer(c_long_long), value :: dptr
        end function cuMemGetAddressRange

        integer(c_int) function cuMemGetAllocationGranularity(granularity, prop, option) &
                bind(C, name="cuMemGetAllocationGranularity")
            import
            integer(c_size_t), intent(inout) :: granularity
            type(CUmemAllocationProp_st), intent(in) :: prop
            integer(c_int), value :: option
        end function cuMemGetAllocationGranularity

        integer(c_int) function cuMemGetAllocationPropertiesFromHandle(prop, handle) &
                bind(C, name="cuMemGetAllocationPropertiesFromHandle")
            import
            type(CUmemAllocationProp_st), intent(inout) :: prop
            integer(c_long_long), value :: handle
        end function cuMemGetAllocationPropertiesFromHandle

        integer(c_int) function cuMemGetHandleForAddressRange(handle, dptr, size, handleType, flags) &
                bind(C, name="cuMemGetHandleForAddressRange")
            import
            type(c_ptr), value :: handle
            integer(c_long_long), value :: dptr
            integer(c_size_t), value :: size
            integer(c_int), value :: handleType
            integer(c_long_long), value :: flags
        end function cuMemGetHandleForAddressRange

        integer(c_int) function cuMemGetInfo(free, total) &
                bind(C, name="cuMemGetInfo_v2")   ! header aliases cuMemGetInfo -> cuMemGetInfo_v2
            import
            integer(c_size_t), intent(inout) :: free
            integer(c_size_t), intent(inout) :: total
        end function cuMemGetInfo

        integer(c_int) function cuMemHostAlloc(pp, bytesize, Flags) &
                bind(C, name="cuMemHostAlloc")
            import
            type(c_ptr), intent(out) :: pp
            integer(c_size_t), value :: bytesize
            integer(c_int), value :: Flags
        end function cuMemHostAlloc

        integer(c_int) function cuMemHostGetDevicePointer(pdptr, p, Flags) &
                bind(C, name="cuMemHostGetDevicePointer_v2")   ! header aliases cuMemHostGetDevicePointer -> cuMemHostGetDevicePointer_v2
            import
            integer(c_long_long), intent(inout) :: pdptr
            type(c_ptr), value :: p
            integer(c_int), value :: Flags
        end function cuMemHostGetDevicePointer

        integer(c_int) function cuMemHostGetFlags(pFlags, p) &
                bind(C, name="cuMemHostGetFlags")
            import
            integer(c_int), intent(inout) :: pFlags
            type(c_ptr), value :: p
        end function cuMemHostGetFlags

        integer(c_int) function cuMemHostRegister(p, bytesize, Flags) &
                bind(C, name="cuMemHostRegister_v2")   ! header aliases cuMemHostRegister -> cuMemHostRegister_v2
            import
            type(c_ptr), value :: p
            integer(c_size_t), value :: bytesize
            integer(c_int), value :: Flags
        end function cuMemHostRegister

        integer(c_int) function cuMemHostUnregister(p) &
                bind(C, name="cuMemHostUnregister")
            import
            type(c_ptr), value :: p
        end function cuMemHostUnregister

        integer(c_int) function cuMemImportFromShareableHandle(handle, osHandle, shHandleType) &
                bind(C, name="cuMemImportFromShareableHandle")
            import
            integer(c_long_long), intent(inout) :: handle
            type(c_ptr), value :: osHandle
            integer(c_int), value :: shHandleType
        end function cuMemImportFromShareableHandle

        integer(c_int) function cuMemMap(ptr, size, offset, handle, flags) &
                bind(C, name="cuMemMap")
            import
            integer(c_long_long), value :: ptr
            integer(c_size_t), value :: size
            integer(c_size_t), value :: offset
            integer(c_long_long), value :: handle
            integer(c_long_long), value :: flags
        end function cuMemMap

        integer(c_int) function cuMemMapArrayAsync(mapInfoList, count, hStream) &
                bind(C, name="cuMemMapArrayAsync")
            import
            type(CUarrayMapInfo_st), intent(inout) :: mapInfoList
            integer(c_int), value :: count
            type(c_ptr), value :: hStream
        end function cuMemMapArrayAsync

        integer(c_int) function cuMemPoolCreate(pool, poolProps) &
                bind(C, name="cuMemPoolCreate")
            import
            type(c_ptr), intent(out) :: pool
            type(CUmemPoolProps_st), intent(in) :: poolProps
        end function cuMemPoolCreate

        integer(c_int) function cuMemPoolDestroy(pool) &
                bind(C, name="cuMemPoolDestroy")
            import
            type(c_ptr), value :: pool
        end function cuMemPoolDestroy

        integer(c_int) function cuMemPoolExportPointer(shareData_out, ptr) &
                bind(C, name="cuMemPoolExportPointer")
            import
            type(CUmemPoolPtrExportData_st), intent(inout) :: shareData_out
            integer(c_long_long), value :: ptr
        end function cuMemPoolExportPointer

        integer(c_int) function cuMemPoolExportToShareableHandle(handle_out, pool, handleType, flags) &
                bind(C, name="cuMemPoolExportToShareableHandle")
            import
            type(c_ptr), value :: handle_out
            type(c_ptr), value :: pool
            integer(c_int), value :: handleType
            integer(c_long_long), value :: flags
        end function cuMemPoolExportToShareableHandle

        integer(c_int) function cuMemPoolGetAccess(flags, memPool, location) &
                bind(C, name="cuMemPoolGetAccess")
            import
            integer(c_int), intent(out) :: flags
            type(c_ptr), value :: memPool
            type(CUmemLocation_st), intent(inout) :: location
        end function cuMemPoolGetAccess

        integer(c_int) function cuMemPoolGetAttribute(pool, attr, value) &
                bind(C, name="cuMemPoolGetAttribute")
            import
            type(c_ptr), value :: pool
            integer(c_int), value :: attr
            type(c_ptr), value :: value
        end function cuMemPoolGetAttribute

        integer(c_int) function cuMemPoolImportFromShareableHandle(pool_out, handle, handleType, flags) &
                bind(C, name="cuMemPoolImportFromShareableHandle")
            import
            type(c_ptr), intent(out) :: pool_out
            type(c_ptr), value :: handle
            integer(c_int), value :: handleType
            integer(c_long_long), value :: flags
        end function cuMemPoolImportFromShareableHandle

        integer(c_int) function cuMemPoolImportPointer(ptr_out, pool, shareData) &
                bind(C, name="cuMemPoolImportPointer")
            import
            integer(c_long_long), intent(inout) :: ptr_out
            type(c_ptr), value :: pool
            type(CUmemPoolPtrExportData_st), intent(inout) :: shareData
        end function cuMemPoolImportPointer

        integer(c_int) function cuMemPoolSetAccess(pool, map, count) &
                bind(C, name="cuMemPoolSetAccess")
            import
            type(c_ptr), value :: pool
            type(CUmemAccessDesc_st), intent(in) :: map
            integer(c_size_t), value :: count
        end function cuMemPoolSetAccess

        integer(c_int) function cuMemPoolSetAttribute(pool, attr, value) &
                bind(C, name="cuMemPoolSetAttribute")
            import
            type(c_ptr), value :: pool
            integer(c_int), value :: attr
            type(c_ptr), value :: value
        end function cuMemPoolSetAttribute

        integer(c_int) function cuMemPoolTrimTo(pool, minBytesToKeep) &
                bind(C, name="cuMemPoolTrimTo")
            import
            type(c_ptr), value :: pool
            integer(c_size_t), value :: minBytesToKeep
        end function cuMemPoolTrimTo

        integer(c_int) function cuMemPrefetchAsync(devPtr, count, dstDevice, hStream) &
                bind(C, name="cuMemPrefetchAsync")
            import
            integer(c_long_long), value :: devPtr
            integer(c_size_t), value :: count
            integer(c_int), value :: dstDevice
            type(c_ptr), value :: hStream
        end function cuMemPrefetchAsync

        integer(c_int) function cuMemPrefetchAsync_v2(devPtr, count, location, flags, hStream) &
                bind(C, name="cuMemPrefetchAsync_v2")
            import
            integer(c_long_long), value :: devPtr
            integer(c_size_t), value :: count
            type(CUmemLocation_st), value :: location
            integer(c_int), value :: flags
            type(c_ptr), value :: hStream
        end function cuMemPrefetchAsync_v2

        integer(c_int) function cuMemRangeGetAttribute(data, dataSize, attribute, devPtr, count) &
                bind(C, name="cuMemRangeGetAttribute")
            import
            type(c_ptr), value :: data
            integer(c_size_t), value :: dataSize
            integer(c_int), value :: attribute
            integer(c_long_long), value :: devPtr
            integer(c_size_t), value :: count
        end function cuMemRangeGetAttribute

        integer(c_int) function cuMemRangeGetAttributes(data, dataSizes, attributes, numAttributes, devPtr, count) &
                bind(C, name="cuMemRangeGetAttributes")
            import
            type(c_ptr), intent(out) :: data
            integer(c_size_t), intent(inout) :: dataSizes
            integer(c_int), intent(out) :: attributes
            integer(c_size_t), value :: numAttributes
            integer(c_long_long), value :: devPtr
            integer(c_size_t), value :: count
        end function cuMemRangeGetAttributes

        integer(c_int) function cuMemRelease(handle) &
                bind(C, name="cuMemRelease")
            import
            integer(c_long_long), value :: handle
        end function cuMemRelease

        integer(c_int) function cuMemRetainAllocationHandle(handle, addr) &
                bind(C, name="cuMemRetainAllocationHandle")
            import
            integer(c_long_long), intent(inout) :: handle
            type(c_ptr), value :: addr
        end function cuMemRetainAllocationHandle

        integer(c_int) function cuMemSetAccess(ptr, size, desc, count) &
                bind(C, name="cuMemSetAccess")
            import
            integer(c_long_long), value :: ptr
            integer(c_size_t), value :: size
            type(CUmemAccessDesc_st), intent(in) :: desc
            integer(c_size_t), value :: count
        end function cuMemSetAccess

        integer(c_int) function cuMemUnmap(ptr, size) &
                bind(C, name="cuMemUnmap")
            import
            integer(c_long_long), value :: ptr
            integer(c_size_t), value :: size
        end function cuMemUnmap

        integer(c_int) function cuMemcpy(dst, src, ByteCount) &
                bind(C, name="cuMemcpy")
            import
            integer(c_long_long), value :: dst
            integer(c_long_long), value :: src
            integer(c_size_t), value :: ByteCount
        end function cuMemcpy

        integer(c_int) function cuMemcpy2DAsync_v2(pCopy, hStream) &
                bind(C, name="cuMemcpy2DAsync_v2")
            import
            type(CUDA_MEMCPY2D_st), intent(in) :: pCopy
            type(c_ptr), value :: hStream
        end function cuMemcpy2DAsync_v2

        integer(c_int) function cuMemcpy2DUnaligned_v2(pCopy) &
                bind(C, name="cuMemcpy2DUnaligned_v2")
            import
            type(CUDA_MEMCPY2D_st), intent(in) :: pCopy
        end function cuMemcpy2DUnaligned_v2

        integer(c_int) function cuMemcpy2D_v2(pCopy) &
                bind(C, name="cuMemcpy2D_v2")
            import
            type(CUDA_MEMCPY2D_st), intent(in) :: pCopy
        end function cuMemcpy2D_v2

        integer(c_int) function cuMemcpy3DAsync_v2(pCopy, hStream) &
                bind(C, name="cuMemcpy3DAsync_v2")
            import
            type(CUDA_MEMCPY3D_st), intent(in) :: pCopy
            type(c_ptr), value :: hStream
        end function cuMemcpy3DAsync_v2

        integer(c_int) function cuMemcpy3DBatchAsync(numOps, opList, failIdx, flags, hStream) &
                bind(C, name="cuMemcpy3DBatchAsync")
            import
            integer(c_size_t), value :: numOps
            type(CUDA_MEMCPY3D_BATCH_OP_st), intent(inout) :: opList
            integer(c_size_t), intent(inout) :: failIdx
            integer(c_long_long), value :: flags
            type(c_ptr), value :: hStream
        end function cuMemcpy3DBatchAsync

        integer(c_int) function cuMemcpy3DPeer(pCopy) &
                bind(C, name="cuMemcpy3DPeer")
            import
            type(CUDA_MEMCPY3D_PEER_st), intent(in) :: pCopy
        end function cuMemcpy3DPeer

        integer(c_int) function cuMemcpy3DPeerAsync(pCopy, hStream) &
                bind(C, name="cuMemcpy3DPeerAsync")
            import
            type(CUDA_MEMCPY3D_PEER_st), intent(in) :: pCopy
            type(c_ptr), value :: hStream
        end function cuMemcpy3DPeerAsync

        integer(c_int) function cuMemcpy3D_v2(pCopy) &
                bind(C, name="cuMemcpy3D_v2")
            import
            type(CUDA_MEMCPY3D_st), intent(in) :: pCopy
        end function cuMemcpy3D_v2

        integer(c_int) function cuMemcpyAsync(dst, src, ByteCount, hStream) &
                bind(C, name="cuMemcpyAsync")
            import
            integer(c_long_long), value :: dst
            integer(c_long_long), value :: src
            integer(c_size_t), value :: ByteCount
            type(c_ptr), value :: hStream
        end function cuMemcpyAsync

        integer(c_int) function cuMemcpyAtoA_v2(dstArray, dstOffset, srcArray, srcOffset, ByteCount) &
                bind(C, name="cuMemcpyAtoA_v2")
            import
            type(c_ptr), value :: dstArray
            integer(c_size_t), value :: dstOffset
            type(c_ptr), value :: srcArray
            integer(c_size_t), value :: srcOffset
            integer(c_size_t), value :: ByteCount
        end function cuMemcpyAtoA_v2

        integer(c_int) function cuMemcpyAtoD_v2(dstDevice, srcArray, srcOffset, ByteCount) &
                bind(C, name="cuMemcpyAtoD_v2")
            import
            integer(c_long_long), value :: dstDevice
            type(c_ptr), value :: srcArray
            integer(c_size_t), value :: srcOffset
            integer(c_size_t), value :: ByteCount
        end function cuMemcpyAtoD_v2

        integer(c_int) function cuMemcpyAtoHAsync_v2(dstHost, srcArray, srcOffset, ByteCount, hStream) &
                bind(C, name="cuMemcpyAtoHAsync_v2")
            import
            type(c_ptr), value :: dstHost
            type(c_ptr), value :: srcArray
            integer(c_size_t), value :: srcOffset
            integer(c_size_t), value :: ByteCount
            type(c_ptr), value :: hStream
        end function cuMemcpyAtoHAsync_v2

        integer(c_int) function cuMemcpyAtoH_v2(dstHost, srcArray, srcOffset, ByteCount) &
                bind(C, name="cuMemcpyAtoH_v2")
            import
            type(c_ptr), value :: dstHost
            type(c_ptr), value :: srcArray
            integer(c_size_t), value :: srcOffset
            integer(c_size_t), value :: ByteCount
        end function cuMemcpyAtoH_v2

        integer(c_int) function cuMemcpyBatchAsync( &
                dsts, srcs, sizes, count, attrs, attrsIdxs, numAttrs, failIdx, hStream) &
                bind(C, name="cuMemcpyBatchAsync")
            import
            integer(c_long_long), intent(inout) :: dsts
            integer(c_long_long), intent(inout) :: srcs
            integer(c_size_t), intent(inout) :: sizes
            integer(c_size_t), value :: count
            type(CUmemcpyAttributes_st), intent(inout) :: attrs
            integer(c_size_t), intent(inout) :: attrsIdxs
            integer(c_size_t), value :: numAttrs
            integer(c_size_t), intent(inout) :: failIdx
            type(c_ptr), value :: hStream
        end function cuMemcpyBatchAsync

        integer(c_int) function cuMemcpyDtoA_v2(dstArray, dstOffset, srcDevice, ByteCount) &
                bind(C, name="cuMemcpyDtoA_v2")
            import
            type(c_ptr), value :: dstArray
            integer(c_size_t), value :: dstOffset
            integer(c_long_long), value :: srcDevice
            integer(c_size_t), value :: ByteCount
        end function cuMemcpyDtoA_v2

        integer(c_int) function cuMemcpyDtoDAsync_v2(dstDevice, srcDevice, ByteCount, hStream) &
                bind(C, name="cuMemcpyDtoDAsync_v2")
            import
            integer(c_long_long), value :: dstDevice
            integer(c_long_long), value :: srcDevice
            integer(c_size_t), value :: ByteCount
            type(c_ptr), value :: hStream
        end function cuMemcpyDtoDAsync_v2

        integer(c_int) function cuMemcpyDtoD_v2(dstDevice, srcDevice, ByteCount) &
                bind(C, name="cuMemcpyDtoD_v2")
            import
            integer(c_long_long), value :: dstDevice
            integer(c_long_long), value :: srcDevice
            integer(c_size_t), value :: ByteCount
        end function cuMemcpyDtoD_v2

        integer(c_int) function cuMemcpyDtoHAsync_v2(dstHost, srcDevice, ByteCount, hStream) &
                bind(C, name="cuMemcpyDtoHAsync_v2")
            import
            type(c_ptr), value :: dstHost
            integer(c_long_long), value :: srcDevice
            integer(c_size_t), value :: ByteCount
            type(c_ptr), value :: hStream
        end function cuMemcpyDtoHAsync_v2

        integer(c_int) function cuMemcpyDtoH_v2(dstHost, srcDevice, ByteCount) &
                bind(C, name="cuMemcpyDtoH_v2")
            import
            type(c_ptr), value :: dstHost
            integer(c_long_long), value :: srcDevice
            integer(c_size_t), value :: ByteCount
        end function cuMemcpyDtoH_v2

        integer(c_int) function cuMemcpyHtoAAsync_v2(dstArray, dstOffset, srcHost, ByteCount, hStream) &
                bind(C, name="cuMemcpyHtoAAsync_v2")
            import
            type(c_ptr), value :: dstArray
            integer(c_size_t), value :: dstOffset
            type(c_ptr), value :: srcHost
            integer(c_size_t), value :: ByteCount
            type(c_ptr), value :: hStream
        end function cuMemcpyHtoAAsync_v2

        integer(c_int) function cuMemcpyHtoA_v2(dstArray, dstOffset, srcHost, ByteCount) &
                bind(C, name="cuMemcpyHtoA_v2")
            import
            type(c_ptr), value :: dstArray
            integer(c_size_t), value :: dstOffset
            type(c_ptr), value :: srcHost
            integer(c_size_t), value :: ByteCount
        end function cuMemcpyHtoA_v2

        integer(c_int) function cuMemcpyHtoDAsync_v2(dstDevice, srcHost, ByteCount, hStream) &
                bind(C, name="cuMemcpyHtoDAsync_v2")
            import
            integer(c_long_long), value :: dstDevice
            type(c_ptr), value :: srcHost
            integer(c_size_t), value :: ByteCount
            type(c_ptr), value :: hStream
        end function cuMemcpyHtoDAsync_v2

        integer(c_int) function cuMemcpyHtoD_v2(dstDevice, srcHost, ByteCount) &
                bind(C, name="cuMemcpyHtoD_v2")
            import
            integer(c_long_long), value :: dstDevice
            type(c_ptr), value :: srcHost
            integer(c_size_t), value :: ByteCount
        end function cuMemcpyHtoD_v2

        integer(c_int) function cuMemcpyPeer(dstDevice, dstContext, srcDevice, srcContext, ByteCount) &
                bind(C, name="cuMemcpyPeer")
            import
            integer(c_long_long), value :: dstDevice
            type(c_ptr), value :: dstContext
            integer(c_long_long), value :: srcDevice
            type(c_ptr), value :: srcContext
            integer(c_size_t), value :: ByteCount
        end function cuMemcpyPeer

        integer(c_int) function cuMemcpyPeerAsync(dstDevice, dstContext, srcDevice, srcContext, ByteCount, hStream) &
                bind(C, name="cuMemcpyPeerAsync")
            import
            integer(c_long_long), value :: dstDevice
            type(c_ptr), value :: dstContext
            integer(c_long_long), value :: srcDevice
            type(c_ptr), value :: srcContext
            integer(c_size_t), value :: ByteCount
            type(c_ptr), value :: hStream
        end function cuMemcpyPeerAsync

        integer(c_int) function cuMemsetD16Async(dstDevice, us, N, hStream) &
                bind(C, name="cuMemsetD16Async")
            import
            integer(c_long_long), value :: dstDevice
            integer(c_short), value :: us
            integer(c_size_t), value :: N
            type(c_ptr), value :: hStream
        end function cuMemsetD16Async

        integer(c_int) function cuMemsetD16_v2(dstDevice, us, N) &
                bind(C, name="cuMemsetD16_v2")
            import
            integer(c_long_long), value :: dstDevice
            integer(c_short), value :: us
            integer(c_size_t), value :: N
        end function cuMemsetD16_v2

        integer(c_int) function cuMemsetD2D16Async(dstDevice, dstPitch, us, Width, Height, hStream) &
                bind(C, name="cuMemsetD2D16Async")
            import
            integer(c_long_long), value :: dstDevice
            integer(c_size_t), value :: dstPitch
            integer(c_short), value :: us
            integer(c_size_t), value :: Width
            integer(c_size_t), value :: Height
            type(c_ptr), value :: hStream
        end function cuMemsetD2D16Async

        integer(c_int) function cuMemsetD2D16_v2(dstDevice, dstPitch, us, Width, Height) &
                bind(C, name="cuMemsetD2D16_v2")
            import
            integer(c_long_long), value :: dstDevice
            integer(c_size_t), value :: dstPitch
            integer(c_short), value :: us
            integer(c_size_t), value :: Width
            integer(c_size_t), value :: Height
        end function cuMemsetD2D16_v2

        integer(c_int) function cuMemsetD2D32Async(dstDevice, dstPitch, ui, Width, Height, hStream) &
                bind(C, name="cuMemsetD2D32Async")
            import
            integer(c_long_long), value :: dstDevice
            integer(c_size_t), value :: dstPitch
            integer(c_int), value :: ui
            integer(c_size_t), value :: Width
            integer(c_size_t), value :: Height
            type(c_ptr), value :: hStream
        end function cuMemsetD2D32Async

        integer(c_int) function cuMemsetD2D32_v2(dstDevice, dstPitch, ui, Width, Height) &
                bind(C, name="cuMemsetD2D32_v2")
            import
            integer(c_long_long), value :: dstDevice
            integer(c_size_t), value :: dstPitch
            integer(c_int), value :: ui
            integer(c_size_t), value :: Width
            integer(c_size_t), value :: Height
        end function cuMemsetD2D32_v2

        integer(c_int) function cuMemsetD2D8Async(dstDevice, dstPitch, uc, Width, Height, hStream) &
                bind(C, name="cuMemsetD2D8Async")
            import
            integer(c_long_long), value :: dstDevice
            integer(c_size_t), value :: dstPitch
            integer(c_signed_char), value :: uc
            integer(c_size_t), value :: Width
            integer(c_size_t), value :: Height
            type(c_ptr), value :: hStream
        end function cuMemsetD2D8Async

        integer(c_int) function cuMemsetD2D8_v2(dstDevice, dstPitch, uc, Width, Height) &
                bind(C, name="cuMemsetD2D8_v2")
            import
            integer(c_long_long), value :: dstDevice
            integer(c_size_t), value :: dstPitch
            integer(c_signed_char), value :: uc
            integer(c_size_t), value :: Width
            integer(c_size_t), value :: Height
        end function cuMemsetD2D8_v2

        integer(c_int) function cuMemsetD32Async(dstDevice, ui, N, hStream) &
                bind(C, name="cuMemsetD32Async")
            import
            integer(c_long_long), value :: dstDevice
            integer(c_int), value :: ui
            integer(c_size_t), value :: N
            type(c_ptr), value :: hStream
        end function cuMemsetD32Async

        integer(c_int) function cuMemsetD32_v2(dstDevice, ui, N) &
                bind(C, name="cuMemsetD32_v2")
            import
            integer(c_long_long), value :: dstDevice
            integer(c_int), value :: ui
            integer(c_size_t), value :: N
        end function cuMemsetD32_v2

        integer(c_int) function cuMemsetD8Async(dstDevice, uc, N, hStream) &
                bind(C, name="cuMemsetD8Async")
            import
            integer(c_long_long), value :: dstDevice
            integer(c_signed_char), value :: uc
            integer(c_size_t), value :: N
            type(c_ptr), value :: hStream
        end function cuMemsetD8Async

        integer(c_int) function cuMemsetD8_v2(dstDevice, uc, N) &
                bind(C, name="cuMemsetD8_v2")
            import
            integer(c_long_long), value :: dstDevice
            integer(c_signed_char), value :: uc
            integer(c_size_t), value :: N
        end function cuMemsetD8_v2

        integer(c_int) function cuMipmappedArrayCreate(pHandle, pMipmappedArrayDesc, numMipmapLevels) &
                bind(C, name="cuMipmappedArrayCreate")
            import
            type(c_ptr), intent(out) :: pHandle
            type(CUDA_ARRAY3D_DESCRIPTOR_st), intent(in) :: pMipmappedArrayDesc
            integer(c_int), value :: numMipmapLevels
        end function cuMipmappedArrayCreate

        integer(c_int) function cuMipmappedArrayDestroy(hMipmappedArray) &
                bind(C, name="cuMipmappedArrayDestroy")
            import
            type(c_ptr), value :: hMipmappedArray
        end function cuMipmappedArrayDestroy

        integer(c_int) function cuMipmappedArrayGetLevel(pLevelArray, hMipmappedArray, level) &
                bind(C, name="cuMipmappedArrayGetLevel")
            import
            type(c_ptr), intent(out) :: pLevelArray
            type(c_ptr), value :: hMipmappedArray
            integer(c_int), value :: level
        end function cuMipmappedArrayGetLevel

        integer(c_int) function cuMipmappedArrayGetMemoryRequirements(memoryRequirements, mipmap, device) &
                bind(C, name="cuMipmappedArrayGetMemoryRequirements")
            import
            type(CUDA_ARRAY_MEMORY_REQUIREMENTS_st), intent(inout) :: memoryRequirements
            type(c_ptr), value :: mipmap
            integer(c_int), value :: device
        end function cuMipmappedArrayGetMemoryRequirements

        integer(c_int) function cuMipmappedArrayGetSparseProperties(sparseProperties, mipmap) &
                bind(C, name="cuMipmappedArrayGetSparseProperties")
            import
            type(CUDA_ARRAY_SPARSE_PROPERTIES_st), intent(inout) :: sparseProperties
            type(c_ptr), value :: mipmap
        end function cuMipmappedArrayGetSparseProperties

        integer(c_int) function cuModuleEnumerateFunctions(functions, numFunctions, mod) &
                bind(C, name="cuModuleEnumerateFunctions")
            import
            type(c_ptr), intent(out) :: functions
            integer(c_int), value :: numFunctions
            type(c_ptr), value :: mod
        end function cuModuleEnumerateFunctions

        integer(c_int) function cuModuleGetFunction(hfunc, hmod, name) &
                bind(C, name="cuModuleGetFunction")
            import
            type(c_ptr), intent(out) :: hfunc
            type(c_ptr), value :: hmod
            character(kind=c_char), dimension(*), intent(in) :: name
        end function cuModuleGetFunction

        integer(c_int) function cuModuleGetFunctionCount(count, mod) &
                bind(C, name="cuModuleGetFunctionCount")
            import
            integer(c_int), intent(inout) :: count
            type(c_ptr), value :: mod
        end function cuModuleGetFunctionCount

        integer(c_int) function cuModuleGetGlobal(dptr, bytes, hmod, name) &
                bind(C, name="cuModuleGetGlobal_v2")   ! header aliases cuModuleGetGlobal -> cuModuleGetGlobal_v2
            import
            integer(c_long_long), intent(inout) :: dptr
            integer(c_size_t), intent(inout) :: bytes
            type(c_ptr), value :: hmod
            character(kind=c_char), dimension(*), intent(in) :: name
        end function cuModuleGetGlobal

        integer(c_int) function cuModuleGetLoadingMode(mode) &
                bind(C, name="cuModuleGetLoadingMode")
            import
            integer(c_int), intent(out) :: mode
        end function cuModuleGetLoadingMode

        integer(c_int) function cuModuleGetSurfRef(pSurfRef, hmod, name) &
                bind(C, name="cuModuleGetSurfRef")
            import
            type(c_ptr), intent(out) :: pSurfRef
            type(c_ptr), value :: hmod
            character(kind=c_char), dimension(*), intent(in) :: name
        end function cuModuleGetSurfRef

        integer(c_int) function cuModuleGetTexRef(pTexRef, hmod, name) &
                bind(C, name="cuModuleGetTexRef")
            import
            type(c_ptr), intent(out) :: pTexRef
            type(c_ptr), value :: hmod
            character(kind=c_char), dimension(*), intent(in) :: name
        end function cuModuleGetTexRef

        integer(c_int) function cuModuleLoad(module, fname) &
                bind(C, name="cuModuleLoad")
            import
            type(c_ptr), intent(out) :: module
            character(kind=c_char), dimension(*), intent(in) :: fname
        end function cuModuleLoad

        integer(c_int) function cuModuleLoadData(module, image) &
                bind(C, name="cuModuleLoadData")
            import
            type(c_ptr), intent(out) :: module
            type(c_ptr), value :: image
        end function cuModuleLoadData

        integer(c_int) function cuModuleLoadDataEx(module, image, numOptions, options, optionValues) &
                bind(C, name="cuModuleLoadDataEx")
            import
            type(c_ptr), intent(out) :: module
            type(c_ptr), value :: image
            integer(c_int), value :: numOptions
            integer(c_int), intent(out) :: options
            type(c_ptr), intent(out) :: optionValues
        end function cuModuleLoadDataEx

        integer(c_int) function cuModuleLoadFatBinary(module, fatCubin) &
                bind(C, name="cuModuleLoadFatBinary")
            import
            type(c_ptr), intent(out) :: module
            type(c_ptr), value :: fatCubin
        end function cuModuleLoadFatBinary

        integer(c_int) function cuModuleUnload(hmod) &
                bind(C, name="cuModuleUnload")
            import
            type(c_ptr), value :: hmod
        end function cuModuleUnload

        integer(c_int) function cuMulticastAddDevice(mcHandle, dev) &
                bind(C, name="cuMulticastAddDevice")
            import
            integer(c_long_long), value :: mcHandle
            integer(c_int), value :: dev
        end function cuMulticastAddDevice

        integer(c_int) function cuMulticastBindAddr(mcHandle, mcOffset, memptr, size, flags) &
                bind(C, name="cuMulticastBindAddr")
            import
            integer(c_long_long), value :: mcHandle
            integer(c_size_t), value :: mcOffset
            integer(c_long_long), value :: memptr
            integer(c_size_t), value :: size
            integer(c_long_long), value :: flags
        end function cuMulticastBindAddr

        integer(c_int) function cuMulticastBindMem(mcHandle, mcOffset, memHandle, memOffset, size, flags) &
                bind(C, name="cuMulticastBindMem")
            import
            integer(c_long_long), value :: mcHandle
            integer(c_size_t), value :: mcOffset
            integer(c_long_long), value :: memHandle
            integer(c_size_t), value :: memOffset
            integer(c_size_t), value :: size
            integer(c_long_long), value :: flags
        end function cuMulticastBindMem

        integer(c_int) function cuMulticastCreate(mcHandle, prop) &
                bind(C, name="cuMulticastCreate")
            import
            integer(c_long_long), intent(inout) :: mcHandle
            type(CUmulticastObjectProp_st), intent(in) :: prop
        end function cuMulticastCreate

        integer(c_int) function cuMulticastGetGranularity(granularity, prop, option) &
                bind(C, name="cuMulticastGetGranularity")
            import
            integer(c_size_t), intent(inout) :: granularity
            type(CUmulticastObjectProp_st), intent(in) :: prop
            integer(c_int), value :: option
        end function cuMulticastGetGranularity

        integer(c_int) function cuMulticastUnbind(mcHandle, dev, mcOffset, size) &
                bind(C, name="cuMulticastUnbind")
            import
            integer(c_long_long), value :: mcHandle
            integer(c_int), value :: dev
            integer(c_size_t), value :: mcOffset
            integer(c_size_t), value :: size
        end function cuMulticastUnbind

        integer(c_int) function cuOccupancyAvailableDynamicSMemPerBlock(dynamicSmemSize, func, numBlocks, blockSize) &
                bind(C, name="cuOccupancyAvailableDynamicSMemPerBlock")
            import
            integer(c_size_t), intent(inout) :: dynamicSmemSize
            type(c_ptr), value :: func
            integer(c_int), value :: numBlocks
            integer(c_int), value :: blockSize
        end function cuOccupancyAvailableDynamicSMemPerBlock

        integer(c_int) function cuOccupancyMaxActiveBlocksPerMultiprocessor( &
                numBlocks, func, blockSize, dynamicSMemSize) &
                bind(C, name="cuOccupancyMaxActiveBlocksPerMultiprocessor")
            import
            integer(c_int), intent(inout) :: numBlocks
            type(c_ptr), value :: func
            integer(c_int), value :: blockSize
            integer(c_size_t), value :: dynamicSMemSize
        end function cuOccupancyMaxActiveBlocksPerMultiprocessor

        integer(c_int) function cuOccupancyMaxActiveBlocksPerMultiprocessorWithFlags( &
                numBlocks, func, blockSize, dynamicSMemSize, flags) &
                bind(C, name="cuOccupancyMaxActiveBlocksPerMultiprocessorWithFlags")
            import
            integer(c_int), intent(inout) :: numBlocks
            type(c_ptr), value :: func
            integer(c_int), value :: blockSize
            integer(c_size_t), value :: dynamicSMemSize
            integer(c_int), value :: flags
        end function cuOccupancyMaxActiveBlocksPerMultiprocessorWithFlags

        integer(c_int) function cuOccupancyMaxActiveClusters(numClusters, func, config) &
                bind(C, name="cuOccupancyMaxActiveClusters")
            import
            integer(c_int), intent(inout) :: numClusters
            type(c_ptr), value :: func
            type(CUlaunchConfig_st), intent(in) :: config
        end function cuOccupancyMaxActiveClusters

        integer(c_int) function cuOccupancyMaxPotentialBlockSize( &
                minGridSize, blockSize, func, blockSizeToDynamicSMemSize, dynamicSMemSize, blockSizeLimit) &
                bind(C, name="cuOccupancyMaxPotentialBlockSize")
            import
            integer(c_int), intent(inout) :: minGridSize
            integer(c_int), intent(inout) :: blockSize
            type(c_ptr), value :: func
            type(c_funptr), value :: blockSizeToDynamicSMemSize
            integer(c_size_t), value :: dynamicSMemSize
            integer(c_int), value :: blockSizeLimit
        end function cuOccupancyMaxPotentialBlockSize

        integer(c_int) function cuOccupancyMaxPotentialBlockSizeWithFlags( &
                minGridSize, blockSize, func, blockSizeToDynamicSMemSize, dynamicSMemSize, blockSizeLimit, flags) &
                bind(C, name="cuOccupancyMaxPotentialBlockSizeWithFlags")
            import
            integer(c_int), intent(inout) :: minGridSize
            integer(c_int), intent(inout) :: blockSize
            type(c_ptr), value :: func
            type(c_funptr), value :: blockSizeToDynamicSMemSize
            integer(c_size_t), value :: dynamicSMemSize
            integer(c_int), value :: blockSizeLimit
            integer(c_int), value :: flags
        end function cuOccupancyMaxPotentialBlockSizeWithFlags

        integer(c_int) function cuOccupancyMaxPotentialClusterSize(clusterSize, func, config) &
                bind(C, name="cuOccupancyMaxPotentialClusterSize")
            import
            integer(c_int), intent(inout) :: clusterSize
            type(c_ptr), value :: func
            type(CUlaunchConfig_st), intent(in) :: config
        end function cuOccupancyMaxPotentialClusterSize

        integer(c_int) function cuParamSetSize(hfunc, numbytes) &
                bind(C, name="cuParamSetSize")
            import
            type(c_ptr), value :: hfunc
            integer(c_int), value :: numbytes
        end function cuParamSetSize

        integer(c_int) function cuParamSetTexRef(hfunc, texunit, hTexRef) &
                bind(C, name="cuParamSetTexRef")
            import
            type(c_ptr), value :: hfunc
            integer(c_int), value :: texunit
            type(c_ptr), value :: hTexRef
        end function cuParamSetTexRef

        integer(c_int) function cuParamSetf(hfunc, offset, value) &
                bind(C, name="cuParamSetf")
            import
            type(c_ptr), value :: hfunc
            integer(c_int), value :: offset
            real(c_float), value :: value
        end function cuParamSetf

        integer(c_int) function cuParamSeti(hfunc, offset, value) &
                bind(C, name="cuParamSeti")
            import
            type(c_ptr), value :: hfunc
            integer(c_int), value :: offset
            integer(c_int), value :: value
        end function cuParamSeti

        integer(c_int) function cuParamSetv(hfunc, offset, ptr, numbytes) &
                bind(C, name="cuParamSetv")
            import
            type(c_ptr), value :: hfunc
            integer(c_int), value :: offset
            type(c_ptr), value :: ptr
            integer(c_int), value :: numbytes
        end function cuParamSetv

        integer(c_int) function cuPointerGetAttribute(data, attribute, ptr) &
                bind(C, name="cuPointerGetAttribute")
            import
            type(c_ptr), value :: data
            integer(c_int), value :: attribute
            integer(c_long_long), value :: ptr
        end function cuPointerGetAttribute

        integer(c_int) function cuPointerGetAttributes(numAttributes, attributes, data, ptr) &
                bind(C, name="cuPointerGetAttributes")
            import
            integer(c_int), value :: numAttributes
            integer(c_int), intent(out) :: attributes
            type(c_ptr), intent(out) :: data
            integer(c_long_long), value :: ptr
        end function cuPointerGetAttributes

        integer(c_int) function cuPointerSetAttribute(value, attribute, ptr) &
                bind(C, name="cuPointerSetAttribute")
            import
            type(c_ptr), value :: value
            integer(c_int), value :: attribute
            integer(c_long_long), value :: ptr
        end function cuPointerSetAttribute

        integer(c_int) function cuSignalExternalSemaphoresAsync(extSemArray, paramsArray, numExtSems, stream) &
                bind(C, name="cuSignalExternalSemaphoresAsync")
            import
            type(c_ptr), intent(out) :: extSemArray
            type(CUDA_EXTERNAL_SEMAPHORE_SIGNAL_PARAMS_st), intent(in) :: paramsArray
            integer(c_int), value :: numExtSems
            type(c_ptr), value :: stream
        end function cuSignalExternalSemaphoresAsync

        integer(c_int) function cuStreamAddCallback(hStream, callback, userData, flags) &
                bind(C, name="cuStreamAddCallback")
            import
            type(c_ptr), value :: hStream
            type(c_funptr), value :: callback
            type(c_ptr), value :: userData
            integer(c_int), value :: flags
        end function cuStreamAddCallback

        integer(c_int) function cuStreamAttachMemAsync(hStream, dptr, length, flags) &
                bind(C, name="cuStreamAttachMemAsync")
            import
            type(c_ptr), value :: hStream
            integer(c_long_long), value :: dptr
            integer(c_size_t), value :: length
            integer(c_int), value :: flags
        end function cuStreamAttachMemAsync

        integer(c_int) function cuStreamBatchMemOp_v2(stream, count, paramArray, flags) &
                bind(C, name="cuStreamBatchMemOp_v2")
            import
            type(c_ptr), value :: stream
            integer(c_int), value :: count
            type(CUstreamBatchMemOpParams_union), intent(inout) :: paramArray
            integer(c_int), value :: flags
        end function cuStreamBatchMemOp_v2

        integer(c_int) function cuStreamBeginCaptureToGraph( &
                hStream, hGraph, dependencies, dependencyData, numDependencies, mode) &
                bind(C, name="cuStreamBeginCaptureToGraph")
            import
            type(c_ptr), value :: hStream
            type(c_ptr), value :: hGraph
            type(c_ptr), intent(out) :: dependencies
            type(CUgraphEdgeData_st), intent(in) :: dependencyData
            integer(c_size_t), value :: numDependencies
            integer(c_int), value :: mode
        end function cuStreamBeginCaptureToGraph

        integer(c_int) function cuStreamBeginCapture_v2(hStream, mode) &
                bind(C, name="cuStreamBeginCapture_v2")
            import
            type(c_ptr), value :: hStream
            integer(c_int), value :: mode
        end function cuStreamBeginCapture_v2

        integer(c_int) function cuStreamCopyAttributes(dst, src) &
                bind(C, name="cuStreamCopyAttributes")
            import
            type(c_ptr), value :: dst
            type(c_ptr), value :: src
        end function cuStreamCopyAttributes

        integer(c_int) function cuStreamCreate(phStream, Flags) &
                bind(C, name="cuStreamCreate")
            import
            type(c_ptr), intent(out) :: phStream
            integer(c_int), value :: Flags
        end function cuStreamCreate

        integer(c_int) function cuStreamCreateWithPriority(phStream, flags, priority) &
                bind(C, name="cuStreamCreateWithPriority")
            import
            type(c_ptr), intent(out) :: phStream
            integer(c_int), value :: flags
            integer(c_int), value :: priority
        end function cuStreamCreateWithPriority

        integer(c_int) function cuStreamDestroy(hStream) &
                bind(C, name="cuStreamDestroy_v2")   ! header aliases cuStreamDestroy -> cuStreamDestroy_v2
            import
            type(c_ptr), value :: hStream
        end function cuStreamDestroy

        integer(c_int) function cuStreamEndCapture(hStream, phGraph) &
                bind(C, name="cuStreamEndCapture")
            import
            type(c_ptr), value :: hStream
            type(c_ptr), intent(out) :: phGraph
        end function cuStreamEndCapture

        integer(c_int) function cuStreamGetAttribute(hStream, attr, value_out) &
                bind(C, name="cuStreamGetAttribute")
            import
            type(c_ptr), value :: hStream
            integer(c_int), value :: attr
            type(CUlaunchAttributeValue_union), intent(inout) :: value_out
        end function cuStreamGetAttribute

        integer(c_int) function cuStreamGetCaptureInfo_v2( &
                hStream, captureStatus_out, id_out, graph_out, dependencies_out, numDependencies_out) &
                bind(C, name="cuStreamGetCaptureInfo_v2")
            import
            type(c_ptr), value :: hStream
            integer(c_int), intent(out) :: captureStatus_out
            integer(c_int64_t), intent(inout) :: id_out
            type(c_ptr), intent(out) :: graph_out
            type(c_ptr), intent(out) :: dependencies_out
            integer(c_size_t), intent(inout) :: numDependencies_out
        end function cuStreamGetCaptureInfo_v2

        integer(c_int) function cuStreamGetCaptureInfo_v3( &
                hStream, captureStatus_out, id_out, graph_out, dependencies_out, edgeData_out, numDependencies_out) &
                bind(C, name="cuStreamGetCaptureInfo_v3")
            import
            type(c_ptr), value :: hStream
            integer(c_int), intent(out) :: captureStatus_out
            integer(c_int64_t), intent(inout) :: id_out
            type(c_ptr), intent(out) :: graph_out
            type(c_ptr), intent(out) :: dependencies_out
            type(CUgraphEdgeData_st), intent(in) :: edgeData_out
            integer(c_size_t), intent(inout) :: numDependencies_out
        end function cuStreamGetCaptureInfo_v3

        integer(c_int) function cuStreamGetCtx(hStream, pctx) &
                bind(C, name="cuStreamGetCtx")
            import
            type(c_ptr), value :: hStream
            type(c_ptr), intent(out) :: pctx
        end function cuStreamGetCtx

        integer(c_int) function cuStreamGetCtx_v2(hStream, pCtx, pGreenCtx) &
                bind(C, name="cuStreamGetCtx_v2")
            import
            type(c_ptr), value :: hStream
            type(c_ptr), intent(out) :: pCtx
            type(c_ptr), intent(out) :: pGreenCtx
        end function cuStreamGetCtx_v2

        integer(c_int) function cuStreamGetDevice(hStream, device) &
                bind(C, name="cuStreamGetDevice")
            import
            type(c_ptr), value :: hStream
            integer(c_int), intent(inout) :: device
        end function cuStreamGetDevice

        integer(c_int) function cuStreamGetFlags(hStream, flags) &
                bind(C, name="cuStreamGetFlags")
            import
            type(c_ptr), value :: hStream
            integer(c_int), intent(inout) :: flags
        end function cuStreamGetFlags

        integer(c_int) function cuStreamGetGreenCtx(hStream, phCtx) &
                bind(C, name="cuStreamGetGreenCtx")
            import
            type(c_ptr), value :: hStream
            type(c_ptr), intent(out) :: phCtx
        end function cuStreamGetGreenCtx

        integer(c_int) function cuStreamGetId(hStream, streamId) &
                bind(C, name="cuStreamGetId")
            import
            type(c_ptr), value :: hStream
            integer(c_long_long), intent(inout) :: streamId
        end function cuStreamGetId

        integer(c_int) function cuStreamGetPriority(hStream, priority) &
                bind(C, name="cuStreamGetPriority")
            import
            type(c_ptr), value :: hStream
            integer(c_int), intent(inout) :: priority
        end function cuStreamGetPriority

        integer(c_int) function cuStreamIsCapturing(hStream, captureStatus) &
                bind(C, name="cuStreamIsCapturing")
            import
            type(c_ptr), value :: hStream
            integer(c_int), intent(out) :: captureStatus
        end function cuStreamIsCapturing

        integer(c_int) function cuStreamQuery(hStream) &
                bind(C, name="cuStreamQuery")
            import
            type(c_ptr), value :: hStream
        end function cuStreamQuery

        integer(c_int) function cuStreamSetAttribute(hStream, attr, value) &
                bind(C, name="cuStreamSetAttribute")
            import
            type(c_ptr), value :: hStream
            integer(c_int), value :: attr
            type(CUlaunchAttributeValue_union), intent(in) :: value
        end function cuStreamSetAttribute

        integer(c_int) function cuStreamSynchronize(hStream) &
                bind(C, name="cuStreamSynchronize")
            import
            type(c_ptr), value :: hStream
        end function cuStreamSynchronize

        integer(c_int) function cuStreamUpdateCaptureDependencies(hStream, dependencies, numDependencies, flags) &
                bind(C, name="cuStreamUpdateCaptureDependencies")
            import
            type(c_ptr), value :: hStream
            type(c_ptr), intent(out) :: dependencies
            integer(c_size_t), value :: numDependencies
            integer(c_int), value :: flags
        end function cuStreamUpdateCaptureDependencies

        integer(c_int) function cuStreamUpdateCaptureDependencies_v2( &
                hStream, dependencies, dependencyData, numDependencies, flags) &
                bind(C, name="cuStreamUpdateCaptureDependencies_v2")
            import
            type(c_ptr), value :: hStream
            type(c_ptr), intent(out) :: dependencies
            type(CUgraphEdgeData_st), intent(in) :: dependencyData
            integer(c_size_t), value :: numDependencies
            integer(c_int), value :: flags
        end function cuStreamUpdateCaptureDependencies_v2

        integer(c_int) function cuStreamWaitEvent(hStream, hEvent, Flags) &
                bind(C, name="cuStreamWaitEvent")
            import
            type(c_ptr), value :: hStream
            type(c_ptr), value :: hEvent
            integer(c_int), value :: Flags
        end function cuStreamWaitEvent

        integer(c_int) function cuStreamWaitValue32_v2(stream, addr, value, flags) &
                bind(C, name="cuStreamWaitValue32_v2")
            import
            type(c_ptr), value :: stream
            integer(c_long_long), value :: addr
            integer(c_int32_t), value :: value
            integer(c_int), value :: flags
        end function cuStreamWaitValue32_v2

        integer(c_int) function cuStreamWaitValue64_v2(stream, addr, value, flags) &
                bind(C, name="cuStreamWaitValue64_v2")
            import
            type(c_ptr), value :: stream
            integer(c_long_long), value :: addr
            integer(c_int64_t), value :: value
            integer(c_int), value :: flags
        end function cuStreamWaitValue64_v2

        integer(c_int) function cuStreamWriteValue32_v2(stream, addr, value, flags) &
                bind(C, name="cuStreamWriteValue32_v2")
            import
            type(c_ptr), value :: stream
            integer(c_long_long), value :: addr
            integer(c_int32_t), value :: value
            integer(c_int), value :: flags
        end function cuStreamWriteValue32_v2

        integer(c_int) function cuStreamWriteValue64_v2(stream, addr, value, flags) &
                bind(C, name="cuStreamWriteValue64_v2")
            import
            type(c_ptr), value :: stream
            integer(c_long_long), value :: addr
            integer(c_int64_t), value :: value
            integer(c_int), value :: flags
        end function cuStreamWriteValue64_v2

        integer(c_int) function cuSurfObjectCreate(pSurfObject, pResDesc) &
                bind(C, name="cuSurfObjectCreate")
            import
            integer(c_long_long), intent(inout) :: pSurfObject
            type(CUDA_RESOURCE_DESC_st), intent(in) :: pResDesc
        end function cuSurfObjectCreate

        integer(c_int) function cuSurfObjectDestroy(surfObject) &
                bind(C, name="cuSurfObjectDestroy")
            import
            integer(c_long_long), value :: surfObject
        end function cuSurfObjectDestroy

        integer(c_int) function cuSurfObjectGetResourceDesc(pResDesc, surfObject) &
                bind(C, name="cuSurfObjectGetResourceDesc")
            import
            type(CUDA_RESOURCE_DESC_st), intent(inout) :: pResDesc
            integer(c_long_long), value :: surfObject
        end function cuSurfObjectGetResourceDesc

        integer(c_int) function cuSurfRefGetArray(phArray, hSurfRef) &
                bind(C, name="cuSurfRefGetArray")
            import
            type(c_ptr), intent(out) :: phArray
            type(c_ptr), value :: hSurfRef
        end function cuSurfRefGetArray

        integer(c_int) function cuSurfRefSetArray(hSurfRef, hArray, Flags) &
                bind(C, name="cuSurfRefSetArray")
            import
            type(c_ptr), value :: hSurfRef
            type(c_ptr), value :: hArray
            integer(c_int), value :: Flags
        end function cuSurfRefSetArray

        integer(c_int) function cuTexObjectCreate(pTexObject, pResDesc, pTexDesc, pResViewDesc) &
                bind(C, name="cuTexObjectCreate")
            import
            integer(c_long_long), intent(inout) :: pTexObject
            type(CUDA_RESOURCE_DESC_st), intent(in) :: pResDesc
            type(CUDA_TEXTURE_DESC_st), intent(in) :: pTexDesc
            type(CUDA_RESOURCE_VIEW_DESC_st), intent(in) :: pResViewDesc
        end function cuTexObjectCreate

        integer(c_int) function cuTexObjectDestroy(texObject) &
                bind(C, name="cuTexObjectDestroy")
            import
            integer(c_long_long), value :: texObject
        end function cuTexObjectDestroy

        integer(c_int) function cuTexObjectGetResourceDesc(pResDesc, texObject) &
                bind(C, name="cuTexObjectGetResourceDesc")
            import
            type(CUDA_RESOURCE_DESC_st), intent(inout) :: pResDesc
            integer(c_long_long), value :: texObject
        end function cuTexObjectGetResourceDesc

        integer(c_int) function cuTexObjectGetResourceViewDesc(pResViewDesc, texObject) &
                bind(C, name="cuTexObjectGetResourceViewDesc")
            import
            type(CUDA_RESOURCE_VIEW_DESC_st), intent(inout) :: pResViewDesc
            integer(c_long_long), value :: texObject
        end function cuTexObjectGetResourceViewDesc

        integer(c_int) function cuTexObjectGetTextureDesc(pTexDesc, texObject) &
                bind(C, name="cuTexObjectGetTextureDesc")
            import
            type(CUDA_TEXTURE_DESC_st), intent(inout) :: pTexDesc
            integer(c_long_long), value :: texObject
        end function cuTexObjectGetTextureDesc

        integer(c_int) function cuTexRefCreate(pTexRef) &
                bind(C, name="cuTexRefCreate")
            import
            type(c_ptr), intent(out) :: pTexRef
        end function cuTexRefCreate

        integer(c_int) function cuTexRefDestroy(hTexRef) &
                bind(C, name="cuTexRefDestroy")
            import
            type(c_ptr), value :: hTexRef
        end function cuTexRefDestroy

        integer(c_int) function cuTexRefGetAddressMode(pam, hTexRef, dim) &
                bind(C, name="cuTexRefGetAddressMode")
            import
            integer(c_int), intent(out) :: pam
            type(c_ptr), value :: hTexRef
            integer(c_int), value :: dim
        end function cuTexRefGetAddressMode

        integer(c_int) function cuTexRefGetAddress(pdptr, hTexRef) &
                bind(C, name="cuTexRefGetAddress_v2")   ! header aliases cuTexRefGetAddress -> cuTexRefGetAddress_v2
            import
            integer(c_long_long), intent(inout) :: pdptr
            type(c_ptr), value :: hTexRef
        end function cuTexRefGetAddress

        integer(c_int) function cuTexRefGetArray(phArray, hTexRef) &
                bind(C, name="cuTexRefGetArray")
            import
            type(c_ptr), intent(out) :: phArray
            type(c_ptr), value :: hTexRef
        end function cuTexRefGetArray

        integer(c_int) function cuTexRefGetBorderColor(pBorderColor, hTexRef) &
                bind(C, name="cuTexRefGetBorderColor")
            import
            real(c_float), intent(inout) :: pBorderColor
            type(c_ptr), value :: hTexRef
        end function cuTexRefGetBorderColor

        integer(c_int) function cuTexRefGetFilterMode(pfm, hTexRef) &
                bind(C, name="cuTexRefGetFilterMode")
            import
            integer(c_int), intent(out) :: pfm
            type(c_ptr), value :: hTexRef
        end function cuTexRefGetFilterMode

        integer(c_int) function cuTexRefGetFlags(pFlags, hTexRef) &
                bind(C, name="cuTexRefGetFlags")
            import
            integer(c_int), intent(inout) :: pFlags
            type(c_ptr), value :: hTexRef
        end function cuTexRefGetFlags

        integer(c_int) function cuTexRefGetFormat(pFormat, pNumChannels, hTexRef) &
                bind(C, name="cuTexRefGetFormat")
            import
            integer(c_int), intent(out) :: pFormat
            integer(c_int), intent(inout) :: pNumChannels
            type(c_ptr), value :: hTexRef
        end function cuTexRefGetFormat

        integer(c_int) function cuTexRefGetMaxAnisotropy(pmaxAniso, hTexRef) &
                bind(C, name="cuTexRefGetMaxAnisotropy")
            import
            integer(c_int), intent(inout) :: pmaxAniso
            type(c_ptr), value :: hTexRef
        end function cuTexRefGetMaxAnisotropy

        integer(c_int) function cuTexRefGetMipmapFilterMode(pfm, hTexRef) &
                bind(C, name="cuTexRefGetMipmapFilterMode")
            import
            integer(c_int), intent(out) :: pfm
            type(c_ptr), value :: hTexRef
        end function cuTexRefGetMipmapFilterMode

        integer(c_int) function cuTexRefGetMipmapLevelBias(pbias, hTexRef) &
                bind(C, name="cuTexRefGetMipmapLevelBias")
            import
            real(c_float), intent(inout) :: pbias
            type(c_ptr), value :: hTexRef
        end function cuTexRefGetMipmapLevelBias

        integer(c_int) function cuTexRefGetMipmapLevelClamp(pminMipmapLevelClamp, pmaxMipmapLevelClamp, hTexRef) &
                bind(C, name="cuTexRefGetMipmapLevelClamp")
            import
            real(c_float), intent(inout) :: pminMipmapLevelClamp
            real(c_float), intent(inout) :: pmaxMipmapLevelClamp
            type(c_ptr), value :: hTexRef
        end function cuTexRefGetMipmapLevelClamp

        integer(c_int) function cuTexRefGetMipmappedArray(phMipmappedArray, hTexRef) &
                bind(C, name="cuTexRefGetMipmappedArray")
            import
            type(c_ptr), intent(out) :: phMipmappedArray
            type(c_ptr), value :: hTexRef
        end function cuTexRefGetMipmappedArray

        integer(c_int) function cuTexRefSetAddress2D(hTexRef, desc, dptr, Pitch) &
                bind(C, name="cuTexRefSetAddress2D_v3")   ! header aliases cuTexRefSetAddress2D -> cuTexRefSetAddress2D_v3
            import
            type(c_ptr), value :: hTexRef
            type(CUDA_ARRAY_DESCRIPTOR_st), intent(in) :: desc
            integer(c_long_long), value :: dptr
            integer(c_size_t), value :: Pitch
        end function cuTexRefSetAddress2D

        integer(c_int) function cuTexRefSetAddressMode(hTexRef, dim, am) &
                bind(C, name="cuTexRefSetAddressMode")
            import
            type(c_ptr), value :: hTexRef
            integer(c_int), value :: dim
            integer(c_int), value :: am
        end function cuTexRefSetAddressMode

        integer(c_int) function cuTexRefSetAddress(ByteOffset, hTexRef, dptr, bytes) &
                bind(C, name="cuTexRefSetAddress_v2")   ! header aliases cuTexRefSetAddress -> cuTexRefSetAddress_v2
            import
            integer(c_size_t), intent(inout) :: ByteOffset
            type(c_ptr), value :: hTexRef
            integer(c_long_long), value :: dptr
            integer(c_size_t), value :: bytes
        end function cuTexRefSetAddress

        integer(c_int) function cuTexRefSetArray(hTexRef, hArray, Flags) &
                bind(C, name="cuTexRefSetArray")
            import
            type(c_ptr), value :: hTexRef
            type(c_ptr), value :: hArray
            integer(c_int), value :: Flags
        end function cuTexRefSetArray

        integer(c_int) function cuTexRefSetBorderColor(hTexRef, pBorderColor) &
                bind(C, name="cuTexRefSetBorderColor")
            import
            type(c_ptr), value :: hTexRef
            real(c_float), intent(inout) :: pBorderColor
        end function cuTexRefSetBorderColor

        integer(c_int) function cuTexRefSetFilterMode(hTexRef, fm) &
                bind(C, name="cuTexRefSetFilterMode")
            import
            type(c_ptr), value :: hTexRef
            integer(c_int), value :: fm
        end function cuTexRefSetFilterMode

        integer(c_int) function cuTexRefSetFlags(hTexRef, Flags) &
                bind(C, name="cuTexRefSetFlags")
            import
            type(c_ptr), value :: hTexRef
            integer(c_int), value :: Flags
        end function cuTexRefSetFlags

        integer(c_int) function cuTexRefSetFormat(hTexRef, fmt, NumPackedComponents) &
                bind(C, name="cuTexRefSetFormat")
            import
            type(c_ptr), value :: hTexRef
            integer(c_int), value :: fmt
            integer(c_int), value :: NumPackedComponents
        end function cuTexRefSetFormat

        integer(c_int) function cuTexRefSetMaxAnisotropy(hTexRef, maxAniso) &
                bind(C, name="cuTexRefSetMaxAnisotropy")
            import
            type(c_ptr), value :: hTexRef
            integer(c_int), value :: maxAniso
        end function cuTexRefSetMaxAnisotropy

        integer(c_int) function cuTexRefSetMipmapFilterMode(hTexRef, fm) &
                bind(C, name="cuTexRefSetMipmapFilterMode")
            import
            type(c_ptr), value :: hTexRef
            integer(c_int), value :: fm
        end function cuTexRefSetMipmapFilterMode

        integer(c_int) function cuTexRefSetMipmapLevelBias(hTexRef, bias) &
                bind(C, name="cuTexRefSetMipmapLevelBias")
            import
            type(c_ptr), value :: hTexRef
            real(c_float), value :: bias
        end function cuTexRefSetMipmapLevelBias

        integer(c_int) function cuTexRefSetMipmapLevelClamp(hTexRef, minMipmapLevelClamp, maxMipmapLevelClamp) &
                bind(C, name="cuTexRefSetMipmapLevelClamp")
            import
            type(c_ptr), value :: hTexRef
            real(c_float), value :: minMipmapLevelClamp
            real(c_float), value :: maxMipmapLevelClamp
        end function cuTexRefSetMipmapLevelClamp

        integer(c_int) function cuTexRefSetMipmappedArray(hTexRef, hMipmappedArray, Flags) &
                bind(C, name="cuTexRefSetMipmappedArray")
            import
            type(c_ptr), value :: hTexRef
            type(c_ptr), value :: hMipmappedArray
            integer(c_int), value :: Flags
        end function cuTexRefSetMipmappedArray

        integer(c_int) function cuThreadExchangeStreamCaptureMode(mode) &
                bind(C, name="cuThreadExchangeStreamCaptureMode")
            import
            integer(c_int), intent(out) :: mode
        end function cuThreadExchangeStreamCaptureMode

        integer(c_int) function cuUserObjectCreate(object_out, ptr, destroy, initialRefcount, flags) &
                bind(C, name="cuUserObjectCreate")
            import
            type(c_ptr), intent(out) :: object_out
            type(c_ptr), value :: ptr
            type(c_funptr), value :: destroy
            integer(c_int), value :: initialRefcount
            integer(c_int), value :: flags
        end function cuUserObjectCreate

        integer(c_int) function cuUserObjectRelease(object, count) &
                bind(C, name="cuUserObjectRelease")
            import
            type(c_ptr), value :: object
            integer(c_int), value :: count
        end function cuUserObjectRelease

        integer(c_int) function cuUserObjectRetain(object, count) &
                bind(C, name="cuUserObjectRetain")
            import
            type(c_ptr), value :: object
            integer(c_int), value :: count
        end function cuUserObjectRetain

        integer(c_int) function cuWaitExternalSemaphoresAsync(extSemArray, paramsArray, numExtSems, stream) &
                bind(C, name="cuWaitExternalSemaphoresAsync")
            import
            type(c_ptr), intent(out) :: extSemArray
            type(CUDA_EXTERNAL_SEMAPHORE_WAIT_PARAMS_st), intent(in) :: paramsArray
            integer(c_int), value :: numExtSems
            type(c_ptr), value :: stream
        end function cuWaitExternalSemaphoresAsync

    end interface

end module cuda_driver
