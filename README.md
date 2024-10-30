# TP-NTT
TP-NTT is a throughput-oriented, fully-pipelined and highly-configurable NTT accelerator for FHE applications.

# Top-Level Parameters of TP-NTT

Below parameters are provided through the top-module `tp_ntt_top.v`.

| NAME | TYPE | DESCRIPTION |
|---|---|---|
| N | int | The ring size, n1 x n2 x n3 x n4. |
| n1 | int | The size of first dimension. |
| n2 | int | The size of second dimension. |
| n3 | int | The size of third dimension. Setting n3 to 1 leads to a 2D decomposition. |
| n4 | int | The size of fourth dimension. Setting n4 to 1 leads to a 3D decomposition. |
| LOGQ | int | bit-length of the coefficient modulus Q, 32 or 64. |
| TP | int | Throughput, defines the level of parallelism. It must be larger than or equal to each dimension and is a power-of-two. |


# Contributors

Emre Koçer - `kocer@sabanciuniv.edu`

Tolun Tosun - `toluntosun@sabanciuniv.edu`

Erkay Savaş - `erkays@sabanciuniv.edu`

-----