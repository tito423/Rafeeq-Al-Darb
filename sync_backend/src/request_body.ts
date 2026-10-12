export class PayloadTooLarge extends Error {}

/** Bound bytes before decoding or parsing, including requests without a length. */
export async function readBoundedJson(request: Pick<Request, 'headers' | 'body'>, limit: number): Promise<unknown> {
	const declared = Number(request.headers.get('content-length') ?? '0');
	if (declared > limit) throw new PayloadTooLarge();
	if (!request.body) return JSON.parse('');

	const reader = request.body.getReader();
	let bytes = new Uint8Array(Math.min(limit, 65_536));
	let length = 0;
	try {
		while (true) {
			const { done, value } = await reader.read();
			if (done) break;
			const required = length + value.byteLength;
			if (required > limit) {
				// A disconnected transport must not turn a size rejection into bad JSON.
				await reader.cancel().catch(() => {});
				throw new PayloadTooLarge();
			}
			if (required > bytes.length) {
				const grown = new Uint8Array(Math.min(limit, Math.max(required, bytes.length * 2)));
				grown.set(bytes.subarray(0, length));
				bytes = grown;
			}
			bytes.set(value, length);
			length = required;
		}
	} finally {
		reader.releaseLock();
	}
	return JSON.parse(new TextDecoder().decode(bytes.subarray(0, length)));
}
