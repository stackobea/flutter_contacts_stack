class ContactFetchOptions {
  final bool withProperties;
  final bool withPhoto;
  final int? batchSize;
  final int? offset;

  const ContactFetchOptions({
    this.withProperties = false,
    this.withPhoto = false,
    this.batchSize,
    this.offset,
  });
}
