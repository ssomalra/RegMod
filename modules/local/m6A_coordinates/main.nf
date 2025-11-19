process M6A_COORDINATES {
        tag "$meta.id"
        label 'process_low'

	conda "bioconda::bedtools=2.31.1"
	container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/bedtools:2.31.1--h13024bc_3' :
        'quay.io/biocontainers/bedtools:2.31.1--h13024bc_3' }"

        input:
        tuple val(meta), path(inference)
        tuple val(meta), path(reads_bed)

	output:
	tuple val(meta), path("${meta.id}_m6A_coordinates_strand.tsv"), emit: m6A_coordinates

	script:
	"""
	# convert CSV to TSV
	sed 's/,/\\t/g' ${inference}/data.site_proba.csv > data.site_proba.tsv

	# get m6A coordinates
	awk -F'\\t' -v OFS='\\t' 'NR > 1 {print \$1, \$2, \$2 + 1}' data.site_proba.tsv > m6A_coordinates.tsv

	# get strand information from reads BED file
	bedtools intersect -wa -wb -a m6A_coordinates.tsv -b $reads_bed > m6A_strand.tsv

	awk -v OFS="\t" '
	# First pass: read m6A_strand.tsv and collect unique coordinate|strand pairs
	FNR==NR {
		coord = \$1 FS \$2 FS \$3
		strand = \$9
		key = coord "|" strand
		uniq[key] = 1
		next
	}

	# Second pass: print coordinate + each unique strand
	{
		coord = \$1 FS \$2 FS \$3
		for (k in uniq) {
			split(k, arr, "|")
		if (arr[1] == coord)
			print \$1, \$2, \$3, arr[2]
		}
	}
	'  m6A_strand.tsv m6A_coordinates.tsv > ${meta.id}_m6A_coordinates_strand.tsv
	#awk -v OFS="\\t" 'FNR==NR {key=\$1 FS \$2 FS \$3; strand[key][\$9]=1; next} {key=\$1 FS \$2 FS \$3; for(s in strand[key]) print \$0, s}' m6A_strand.tsv m6A_coordinates.tsv > ${meta.id}_m6A_coordinates_strand.tsv
	"""
}
