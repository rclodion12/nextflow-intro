#!/usr/bin/env nextflow


params.bowtie_index = "$baseDir/data/db/FN433596"
params.reads = "$baseDir/data"
readChannel = Channel.fromFilePairs("${params.reads}/*{1,2}.fastq.gz")
params.nb_cpus = 3


process mapping {

	input :
		set pair_id, file(reads) from readChannel

	output :
		set pair_id, file("*.sam") into mappChannel

	script :
		"""
		bowtie2 -q -1 ${reads[0]} -2 ${reads[1]} -x ${params.bowtie_index} -S ${pair_id}.sam -p ${params.nb_cpus}
		"""
}

process samtools_view {

	input :
		set pair_id, file(mapping) from mappChannel

	output :
		set pair_id, file("*.bam") into ViewChannel

	script :
		"""
		samtools view -S -@ ${params.nb_cpus} -b -o ${pair_id}.bam ${mapping}
		"""
}


process samtools_sort {

	input :
		set pair_id, file(sam_view) from ViewChannel

	output :
		set pair_id, file("sorted_*.bam") into SortChannel

	script :
		"""
		samtools sort -@ ${params.nb_cpus} -o sorted_${pair_id}.bam ${sam_view}
		"""
}


process bedtools {

	input :
		set pair_id, file(sam_sort) from SortChannel

	output :
		set pair_id, file("*.gcbout") into bedtoolsChannel

	script :
		"""
		bedtools genomecov -ibam ${sam_sort} -d > ${pair_id}.gcbout
		"""
}


process coverageStats {

	publishDir "${params.results}", mode: 'copy'
	input :
		set pair_id, file(bed) from bedtoolsChannel

	output :
		stdout coverageChannel

	script :
		"""
		bed2coverage ${bed} 
		"""
}

coverageChannel.subscribe{ println it }
