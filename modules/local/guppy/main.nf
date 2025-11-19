process GUPPY_BASECALL {
	tag "$meta.id"
	label 'process_high'
	
	queue 'gpu'

	beforeScript = 'module load python/gpu'

	input:
	tuple val(meta), path(fast5_dir), val(flowcell_id), val(sequencing_kit)

	output:
	tuple val(meta), path("${meta.id}_guppy"), emit: guppy
	path "versions.yml", emit: versions

	script:
	"""
	# ensure that guppy is in the path
	export PATH=\$PATH:${params.guppy_package}/bin

	# run guppy basecalling
	guppy_basecaller -i $fast5_dir -s ${meta.id}_guppy --flowcell $flowcell_id --kit $sequencing_kit --fast5_out --num_callers ${task.cpus}  --gpu_runners_per_device 1

	cat <<-END_VERSIONS > versions.yml
	"${task.process}":
	    guppy: \$(guppy_basecaller --version | head -n 1)
	END_VERSIONS
	"""
}
